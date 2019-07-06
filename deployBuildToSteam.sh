#!/bin/sh

BUILD_VERSION=$1
STEAM_USER=$2
STEAM_PASSWORD=$3
STORAGE_SERVER_SECRET=$4
ARTIFACTORY_USER=$5
ARTIFACTORY_PASSWORD=$6
RELEASE_VERSION=$7

BUILDER_DIR=SteamContentBuilder

rm -r $BUILDER_DIR || true
rm -rf SteamContentBuilder*
rm -rf WindowsNoEditor*

wget --http-user=$ARTIFACTORY_USER --http-password=$ARTIFACTORY_PASSWORD https://artifactory.valhalla-game.com/artifactory/list/binary-release-local/SteamContentBuilder.zip
unzip SteamContentBuilder.zip

chmod +x $BUILDER_DIR/builder_linux/linux32/steamcmd
chmod +x $BUILDER_DIR/builder_linux/steamcmd.sh

curl -sS -H "Authorization: $STORAGE_SERVER_SECRET" "https://binary-storage.valhalla-game.com/storage?path=valhalla-windows-client&name=WindowsNoEditor$BUILD_VERSION$RELEASE_VERSION.zip" --output "WindowsNoEditor$BUILD_VERSION$RELEASE_VERSION.zip"
unzip WindowsNoEditor$BUILD_VERSION$RELEASE_VERSION.zip -d $BUILDER_DIR/content/windows_content

APP_BUILD_NAME="dev-app_build_763550.vdf"

if [ "$RELEASE_VERSION" = "Development" ]; then
	APP_BUILD_NAME="dev-app_build_763550.vdf"
elif [ "$RELEASE_VERSION" = "DebugGame" ]; then
	APP_BUILD_NAME="dev-app_build_763550.vdf"
elif [ "$RELEASE_VERSION" = "Shipping" ]; then
	APP_BUILD_NAME="prod-app_build_763550.vdf"
fi

curl https://raw.githubusercontent.com/saiaku-gaming/jenkins-common/master/$APP_BUILD_NAME > $BUILDER_DIR/scripts/app_build_763550.vdf
curl https://raw.githubusercontent.com/saiaku-gaming/jenkins-common/master/depot_build_763551.vdf > $BUILDER_DIR/scripts/depot_build_763551.vdf

sed -i "s/\$BUILD_VERSION/$BUILD_VERSION/g" $BUILDER_DIR/scripts/app_build_763550.vdf

#If below does not work, try installing support for 32-bit os.
#sudo apt-get install libc6:i386 libncurses5:i386 libstdc++6:i386

/bin/bash $BUILDER_DIR/builder_linux/steamcmd.sh +login $STEAM_USER $STEAM_PASSWORD +run_app_build $(pwd)/$BUILDER_DIR/scripts/app_build_763550.vdf +quit
