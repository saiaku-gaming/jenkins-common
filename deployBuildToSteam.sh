#!/bin/sh

set -x
set -e

BUILD_VERSION=$1
STEAM_USER=$2
STEAM_PASSWORD=$3
STORAGE_SERVER_SECRET=$4
RELEASE_TYPE=$5
CLIENT_NAME=$6
APP_ID=$7
DEPOT_ID=$8

if [ "$RELEASE_TYPE" = "Playtest" ]; then
	RELEASE_VERSION="Shipping"
else
	RELEASE_VERSION="$RELEASE_TYPE"
fi

BUILDER_DIR=SteamContentBuilder

# Remove previous zip file
rm -rf Windows*

if [ -d "$BUILDER_DIR" ]; then
	echo "NOTE: Skipping SteamContentBuilder refresh for maximum speed!"
	rm -rf $BUILDER_DIR/content/windows_content
else
	rm SteamContentBuilder.zip || true

	wget https://valhalla-game.com/files/SteamContentBuilder.zip
	unzip SteamContentBuilder.zip

	chmod +x $BUILDER_DIR/builder_linux/linux32/steamcmd
	chmod +x $BUILDER_DIR/builder_linux/steamcmd.sh

fi

ZIP_PATH="/opt/binary-storage/$CLIENT_NAME/Windows$BUILD_VERSION$RELEASE_VERSION.zip"

if [ -f $ZIP_PATH ]; then
	unzip $ZIP_PATH -d $BUILDER_DIR/content/windows_content
else 
	curl -sS -H "Authorization: $STORAGE_SERVER_SECRET" "https://binary-storage.valhalla-game.com/storage?path=$CLIENT_NAME&name=Windows$BUILD_VERSION$RELEASE_VERSION.zip" --output "Windows$BUILD_VERSION$RELEASE_VERSION.zip"
	unzip Windows$BUILD_VERSION$RELEASE_VERSION.zip -d $BUILDER_DIR/content/windows_content
fi

echo "$APP_ID" > $BUILDER_DIR/content/windows_content/steam_appid.txt

APP_BUILD_NAME="dev-app_build_$APP_ID.vdf"
DEPO_BUILD_NAME="dev-depot_build_$DEPOT_ID.vdf"

if [ "$RELEASE_TYPE" = "Development" ]; then
	APP_BUILD_NAME="dev-app_build_$APP_ID.vdf"
	DEPO_BUILD_NAME="dev-depot_build_$DEPOT_ID.vdf"
elif [ "$RELEASE_TYPE" = "DebugGame" ]; then
	APP_BUILD_NAME="dev-app_build_$APP_ID.vdf"
	DEPO_BUILD_NAME="dev-depot_build_$DEPOT_ID.vdf"
elif [ "$RELEASE_TYPE" = "Shipping" ]; then
	APP_BUILD_NAME="prod-app_build_$APP_ID.vdf"
	DEPO_BUILD_NAME="prod-depot_build_$DEPOT_ID.vdf"
elif [ "$RELEASE_TYPE" = "Playtest" ]; then
	APP_BUILD_NAME="playtest-app_build_$APP_ID.vdf"
	DEPO_BUILD_NAME="playtest-depot_build_$DEPOT_ID.vdf"
fi

curl https://raw.githubusercontent.com/saiaku-gaming/jenkins-common/master/$APP_BUILD_NAME > $BUILDER_DIR/scripts/app_build_$APP_ID.vdf
curl https://raw.githubusercontent.com/saiaku-gaming/jenkins-common/master/$DEPO_BUILD_NAME > $BUILDER_DIR/scripts/depot_build_$DEPOT_ID.vdf

sed -i "s/\$BUILD_VERSION/$BUILD_VERSION/g" $BUILDER_DIR/scripts/app_build_$APP_ID.vdf

#If below does not work, try installing support for 32-bit os.
#sudo apt-get install libc6:i386 libncurses5:i386 libstdc++6:i386

/bin/bash $BUILDER_DIR/builder_linux/steamcmd.sh +login $STEAM_USER $STEAM_PASSWORD +run_app_build $(pwd)/$BUILDER_DIR/scripts/app_build_$APP_ID.vdf +quit
