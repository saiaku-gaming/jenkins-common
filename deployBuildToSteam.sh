#!/bin/sh

BUILD_VERSION=$1
STEAM_USER=$2
STEAM_PASSWORD=$3
FTP_PASSWORD=$4
RELEASE_VERSION=$5

BUILDER_DIR=SteamContentBuilder

rm -r $BUILDER_DIR || true

wget -m -nH --cut-dirs=1 -P $BUILDER_DIR ftp://jenkins:$FTP_PASSWORD@ftp.valhalla-game.com/$BUILDER_DIR
chmod +x $BUILDER_DIR/builder_linux/linux32/steamcmd
chmod +x $BUILDER_DIR/builder_linux/steamcmd.sh

wget -m -nH --cut-dirs=2 -P $BUILDER_DIR/content/windows_content ftp://jenkins:$FTP_PASSWORD@ftp.valhalla-game.com/$BUILD_VERSION$RELEASE_VERSION/WindowsNoEditor

APP_BUILD_NAME="dev-app_build_763550.vdf"

if [ "$5" = "development" ]; then
	APP_BUILD_NAME="dev-app_build_763550.vdf"
elif [ "$5" = "production" ]; then
	APP_BUILD_NAME="prod-app_build_763550.vdf"
fi

curl https://raw.githubusercontent.com/saiaku-gaming/jenkins-common/master/$APP_BUILD_NAME > $BUILDER_DIR/scripts/app_build_763550.vdf
curl https://raw.githubusercontent.com/saiaku-gaming/jenkins-common/master/depot_build_763551.vdf > $BUILDER_DIR/scripts/depot_build_763551.vdf

sed -i "s/\$BUILD_VERSION/$BUILD_VERSION/g" $BUILDER_DIR/scripts/app_build_763550.vdf

#If below does not work, try installing support for 32-bit os.
#sudo apt-get install libc6:i386 libncurses5:i386 libstdc++6:i386

/bin/bash $BUILDER_DIR/builder_linux/steamcmd.sh +login $STEAM_USER $STEAM_PASSWORD +run_app_build $(pwd)/$BUILDER_DIR/scripts/app_build_763550.vdf +quit
