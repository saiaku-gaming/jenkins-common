#!/bin/sh

BUILD_VERSION=$1
STEAM_USER=$2
STEAM_PASSWORD=$3

BUILDER_DIR="/home/valhalla/steamworks_sdk/sdk/tools/ContentBuilder"

rm -rf "$BUILDER_DIR/content/windows_content"
cp -r "/home/valhalla/builds/$BUILD_VERSION/WindowsClient/WindowsNoEditor" "$BUILDER_DIR/content/windows_content"

/home/valhalla/steamworks_sdk/sdk/tools/ContentBuilder/builder_linux/steamcmd.sh +login $STEAM_USER $STEAM_PASSWORD +run_app_build $BUILDER_DIR/scripts/app_build_763550.vdf +quit

