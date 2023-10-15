#!/bin/bash

set -e

command -v curl > /dev/null 2>&1 || { echo >&2 "I require curl but it's not installed. Install it. Aborting."; exit 1; }
command -v javac > /dev/null 2>&1 || { echo >&2 "I require openjdk11 but it's not installed. Install it. Aborting."; exit 1; }
command -v unzip > /dev/null 2>&1 || { echo >&2 "I require unzip but it's not installed. Install it. Aborting."; exit 1; }
command -v wget > /dev/null 2>&1 || { echo >&2 "I require wget but it's not installed. Install it. Aborting."; exit 1; }

ADB="/tmp/platform-tools/adb"
AAPT="/tmp/build-tools/**/aapt"
DX="/tmp/build-tools/**/dx"
ZIPALIGN="/tmp/build-tools/**/zipalign"
APKSIGNER="/tmp/build-tools/**/apksigner"
PLATFORM="/tmp/platforms/android-[0-9]*/android.jar"
SDKMANAGER="/tmp/commandline-tools/cmdline-tools/bin/sdkmanager"

#[[ -e /tmp/build-tools.zip ]] || wget -O /tmp/build-tools.zip 'https://dl.google.com/android/repository/build-tools_r25-linux.zip' && [[ -d /tmp/build-tools ]] || unzip /tmp/build-tools.zip -d /tmp/build-tools/
[[ -e /tmp/commandline-tools.zip ]] || wget -O /tmp/commandline-tools.zip 'https://dl.google.com/android/repository/commandlinetools-linux-9123335_latest.zip' && [[ -d /tmp/commandline-tools ]] || unzip /tmp/commandline-tools.zip -d /tmp/commandline-tools/
#[[ -e /tmp/platforms.zip ]] || wget -O /tmp/platforms.zip 'https://dl.google.com/android/repository/android-16_r05.zip' && [[ -d /tmp/platforms ]] || unzip /tmp/platforms.zip -d /tmp/platforms/
#[[ -e /tmp/platform-tools.zip ]] || wget -O /tmp/platform-tools.zip 'https://dl.google.com/android/repository/platform-tools-latest-linux.zip' && [[ -d /tmp/platform-tools ]] || unzip /tmp/platform-tools.zip -d /tmp/platform-tools/

yes | $SDKMANAGER --install "platform-tools" "platforms;android-29" "build-tools;29.0.2" --sdk_root=/tmp/

rm -rfd test/
rm -rfd *.dex
rm -rfd obj/*
rm -rfd **/R.java
rm -rfd mykey.keystore

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

	echo "Cleaning up the mess..."
	rm -rfd *.dex
	rm -rfd obj/*
	rm -rfd src/com/example/app/R.java
	rm -rfd mykey.keystore

	$ADB install -r bin/hello.unaligned.apk
	$ADB shell am start -n com.example.app/.MainActivity
 	exit
fi

./gradlew clean
./gradlew build

echo "Cleaning up the mess..."
rm -rfd test/
rm -rfd *.dex
rm -rfd obj/*
rm -rfd **/R.java
rm -rfd mykey.keystore

echo "All done! Use build.sh --install to install the app on your device."

exit
