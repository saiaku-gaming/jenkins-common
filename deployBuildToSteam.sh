#!/bin/sh

BUILD_VERSION=$1
STEAM_USER=$2
STEAM_PASSWORD=$3
FTP_PASSWORD=$4

BUILDER_DIR=SteamContentBuilder

rm -r $BUILDER_DIR || true

wget -m -nH --cut-dirs=1 -P $BUILDER_DIR ftp://jenkins:$FTP_PASSWORD@ftp.valhalla-game.com/$BUILDER_DIR
chmod +x $BUILDER_DIR/builder_linux/linux32/steamcmd
chmod +x $BUILDER_DIR/builder_linux/steamcmd.sh

wget -m -nH --cut-dirs=2 -P $BUILDER_DIR/content/windows_content ftp://jenkins:$FTP_PASSWORD@ftp.valhalla-game.com/$BUILD_VERSION/WindowsNoEditor

curl https://raw.githubusercontent.com/saiaku-gaming/jenkins-common/master/app_build_763550.vdf > $BUILDER_DIR/scripts/app_build_763550.vdf
curl https://raw.githubusercontent.com/saiaku-gaming/jenkins-common/master/depot_build_763551.vdf > $BUILDER_DIR/scripts/depot_build_763551.vdf

/bin/bash $BUILDER_DIR/builder_linux/steamcmd.sh +login $STEAM_USER $STEAM_PASSWORD +run_app_build $BUILDER_DIR/scripts/app_build_763550.vdf +quit
