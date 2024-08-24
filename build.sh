#!/bin/bash

set -e

command -v javac > /dev/null 2>&1 || { echo >&2 "I require openjdk-17 but it's not installed. Install it. Aborting."; exit 1; }
command -v unzip > /dev/null 2>&1 || { echo >&2 "I require unzip but it's not installed. Install it. Aborting."; exit 1; }
command -v wget > /dev/null 2>&1 || { echo >&2 "I require wget but it's not installed. Install it. Aborting."; exit 1; }

[[ -e /tmp/commandline-tools.zip ]] || wget -O /tmp/commandline-tools.zip 'https://dl.google.com/android/repository/commandlinetools-linux-9123335_latest.zip' && [[ -d /tmp/commandline-tools ]] || unzip /tmp/commandline-tools.zip -d /tmp/commandline-tools/

ANDROID_HOME="/tmp/"
ADB="/tmp/platform-tools/adb"
SDKMANAGER="/tmp/commandline-tools/cmdline-tools/bin/sdkmanager"

yes | $SDKMANAGER --install "platform-tools" "platforms;android-30" "build-tools;30.0.0" --sdk_root=/tmp/

if [ "$1" == "--install" ]; then
	echo "Waiting for device..."
	$ADB wait-for-device
	find . -name "*.apk" | xargs $ADB install -r
 	exit
fi

chmod +x gradlew
./gradlew clean
./gradlew build

echo "All done! Use build.sh --install to install the app on your device."
