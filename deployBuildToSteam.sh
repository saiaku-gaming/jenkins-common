#!/bin/sh

BUILD_VERSION=$1
STEAM_USER=$2
STEAM_PASSWORD=$3
FTP_PASSWORD=$4

BUILDER_DIR="/home/valhalla/sdk/tools/ContentBuilder"
rm -r $BUILDER_DIR/content/windows_content
wget -m -nH --cut-dirs=2 -P $BUILDER_DIR/content/windows_content ftp://jenkins:$4@ftp.valhalla-game.com/$1/WindowsClient/WindowsNoEditor
#rsync -ax --delete "jenkins@valhalla-game.com:/home/valhalla/builds/$BUILD_VERSION/WindowsClient/WindowsNoEditor/" "$BUILDER_DIR/content/windows_content"

/home/valhalla/sdk/tools/ContentBuilder/builder_linux/steamcmd.sh +login $STEAM_USER $STEAM_PASSWORD +run_app_build $BUILDER_DIR/scripts/app_build_763550.vdf +quit
