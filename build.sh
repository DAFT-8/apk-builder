#!/bin/bash

set -e

command -v curl > /dev/null 2>&1 || { echo >&2 "I require curl but it's not installed. Install it. Aborting."; exit 1; }
command -v javac > /dev/null 2>&1 || { echo >&2 "I require openjdk8 but it's not installed. Install it. Aborting."; exit 1; }
command -v unzip > /dev/null 2>&1 || { echo >&2 "I require unzip but it's not installed. Install it. Aborting."; exit 1; }
command -v wget > /dev/null 2>&1 || { echo >&2 "I require wget but it's not installed. Install it. Aborting."; exit 1; }

[[ -e /tmp/build-tools.zip ]] || wget -O /tmp/build-tools.zip 'https://dl.google.com/android/repository/build-tools_r25-linux.zip' && [[ -d /tmp/build-tools ]] || unzip /tmp/build-tools.zip -d /tmp/build-tools/
[[ -e /tmp/platforms.zip ]] || wget -O /tmp/platforms.zip 'https://dl.google.com/android/repository/android-16_r05.zip' && [[ -d /tmp/platforms ]] || unzip /tmp/platforms.zip -d /tmp/platforms/
[[ -e /tmp/platform-tools.zip ]] || wget -O /tmp/platform-tools.zip 'https://dl.google.com/android/repository/platform-tools-latest-linux.zip' && [[ -d /tmp/platform-tools ]] || unzip /tmp/platform-tools.zip -d /tmp/platform-tools/

ADB="/tmp/platform-tools/platform-tools/adb"
AAPT="/tmp/build-tools/android-[0-9]*/aapt"
DX="/tmp/build-tools/android-[0-9]*/dx"
ZIPALIGN="/tmp/build-tools/android-[0-9]*/zipalign"
APKSIGNER="/tmp/build-tools/android-[0-9]*/apksigner"
PLATFORM="/tmp/platforms/android-[0-9]*/android.jar"

if [ "$1" == "--install" ]; then
	echo "Waiting for device..."
	$ADB wait-for-device
	find . -name "*.apk" | xargs $ADB install -r
 	exit
elif [ "$1" == "--test" ]; then
	[[ -d test ]] || mkdir test
	cd test
	[[ -d libs ]] || mkdir libs
	[[ -d obj ]] || mkdir obj
	[[ -d bin ]] || mkdir bin
	[[ -d src/com/example/app ]] || mkdir -p src/com/example/app
	[[ -d res/layout ]] || mkdir -p res/layout
	[[ -d res/values ]] || mkdir res/values
	[[ -d res/drawable ]] || mkdir res/drawable
	echo "Cleaning..."
	rm -rfd obj/*
	rm -rfd src/com/example/app/R.java
	rm -rfd mykey.keystore
	echo "Launching..."
	echo -e "<?xml version='1.0'?>
	<manifest xmlns:a='http://schemas.android.com/apk/res/android' package='com.example.helloandroid' a:versionCode='0' a:versionName='0'>
		<application a:label='A Hello Android'>
			<activity a:name='com.example.helloandroid.MainActivity'>
				 <intent-filter>
					<category a:name='android.intent.category.LAUNCHER'/>
					<action a:name='android.intent.action.MAIN'/>
				 </intent-filter>
			</activity>
		</application>
	</manifest>
	" >AndroidManifest.xml

	echo -e 'package com.example.helloandroid;

	import android.app.Activity;
	import android.os.Bundle;

	public class MainActivity extends Activity {
	   @Override
	   protected void onCreate(Bundle savedInstanceState) {
		  super.onCreate(savedInstanceState);
		  setContentView(R.layout.activity_main);
	   }
	}
	' >src/com/example/app/MainActivity.java

	echo -e '<resources>
	   <string name="app_name">A Hello Android</string>
	   <string name="hello_msg">Hello Android!</string>
	   <string name="menu_settings">Settings</string>
	   <string name="title_activity_main">MainActivity</string>
	</resources>
	' >res/values/strings.xml

	echo -e '<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools"
	   android:layout_width="match_parent"
	   android:layout_height="match_parent" >

	   <TextView
		  android:layout_width="wrap_content"
		  android:layout_height="wrap_content"
		  android:layout_centerHorizontal="true"
		  android:layout_centerVertical="true"
		  android:text="@string/hello_msg"
		  tools:context=".MainActivity" />
	</RelativeLayout>
	' >res/layout/activity_main.xml

	echo "Generating R.java file..."
	$AAPT package -f -m -J src -M AndroidManifest.xml -S res -I $PLATFORM

	echo "Compiling..."
	javac -d obj -classpath src -bootclasspath $PLATFORM -source 1.7 -target 1.7 src/com/example/app/*.java

	echo "Translating to Dalvik byte code..."
	$DX --dex --output=classes.dex obj/

	echo "Making APK..."
	$AAPT package -f -m -F bin/hello.unaligned.apk -M AndroidManifest.xml -S res -I $PLATFORM
	$AAPT add bin/hello.unaligned.apk classes.dex

	echo "Aligning and signing APK..."
	keytool -genkeypair -validity 365 -keystore mykey.keystore -keyalg RSA -keysize 2048
	$APKSIGNER sign --ks mykey.keystore bin/hello.unaligned.apk
	#$ZIPALIGN -f 4 bin/hello.unaligned.apk bin/hello.apk

	$ADB install -r bin/hello.unaligned.apk
	$ADB shell am start -n com.example.app/.MainActivity
 	exit
fi

[[ -d libs ]] || mkdir libs
[[ -d obj ]] || mkdir obj
[[ -d bin ]] || mkdir bin

echo "Cleaning..."
rm -rfd obj/*
rm -rfd **/R.java
rm -rfd mykey.keystore

cd $(dirname $(find . -name "AndroidManifest.xml"))

echo "Generating R.java file..."
$AAPT package -f -m -J src -M AndroidManifest.xml -S res -I $PLATFORM

echo "Compiling..."
find . -name "*.java" | xargs javac -d obj -classpath src -bootclasspath $PLATFORM -source 1.7 -target 1.7

echo "Translating to Dalvik byte code..."
$DX --dex --output=classes.dex obj/

echo "Making APK..."
$AAPT package -f -m -F bin/debug.unaligned.apk -M AndroidManifest.xml -S res -I $PLATFORM
$AAPT add bin/debug.unaligned.apk classes.dex

echo "Aligning and signing APK..."
keytool -genkeypair -validity 365 -keystore mykey.keystore -keyalg RSA -keysize 2048
$APKSIGNER sign --ks mykey.keystore bin/debug.unaligned.apk
#$ZIPALIGN -f 4 bin/hello.unaligned.apk bin/hello.apk

echo "All done! Apk at bin. Use --install to install it on your device."

exit
