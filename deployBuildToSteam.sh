#!/bin/sh

set -x
set -e

BUILD_VERSION=$1
STEAM_USER=$2
STEAM_PASSWORD=$3
STORAGE_SERVER_SECRET=$4
RELEASE_VERSION=$5
CLIENT_NAME=$6
APP_ID=$7
DEPOT_ID=$8
if [ "$9" = "local" ]; then
      USE_LOCAL=true
else
      USE_LOCAL=false
fi

BUILDER_DIR=SteamContentBuilder

rm -rf Windows*

if [ "$USE_LOCAL" = "true" ]; then
	echo "NOTE: Skipping SteamContentBuilder refresh for maximum speed!"
	rm -rf $BUILDER_DIR/content/windows_content
	cp "/opt/binary-storage/$CLIENT_NAME/Windows$BUILD_VERSION$RELEASE_VERSION.zip" .
else
	rm -r $BUILDER_DIR || true
	rm SteamContentBuilder.zip || true

	wget https://valhalla-game.com/files/SteamContentBuilder.zip
	unzip SteamContentBuilder.zip

	chmod +x $BUILDER_DIR/builder_linux/linux32/steamcmd
	chmod +x $BUILDER_DIR/builder_linux/steamcmd.sh

	curl -sS -H "Authorization: $STORAGE_SERVER_SECRET" "https://binary-storage.valhalla-game.com/storage?path=$CLIENT_NAME&name=Windows$BUILD_VERSION$RELEASE_VERSION.zip" --output "Windows$BUILD_VERSION$RELEASE_VERSION.zip"
fi

unzip Windows$BUILD_VERSION$RELEASE_VERSION.zip -d $BUILDER_DIR/content/windows_content


APP_BUILD_NAME="dev-app_build_$APP_ID.vdf"
DEPO_BUILD_NAME="dev-depot_build_$DEPOT_ID.vdf"

if [ "$RELEASE_VERSION" = "Development" ]; then
	APP_BUILD_NAME="dev-app_build_$APP_ID.vdf"
	DEPO_BUILD_NAME="dev-depot_build_$DEPOT_ID.vdf"
elif [ "$RELEASE_VERSION" = "DebugGame" ]; then
	APP_BUILD_NAME="dev-app_build_$APP_ID.vdf"
	DEPO_BUILD_NAME="dev-depot_build_$DEPOT_ID.vdf"
elif [ "$RELEASE_VERSION" = "Shipping" ]; then
	APP_BUILD_NAME="prod-app_build_$APP_ID.vdf"
	DEPO_BUILD_NAME="prod-depot_build_$DEPOT_ID.vdf"
fi

curl https://raw.githubusercontent.com/saiaku-gaming/jenkins-common/master/$APP_BUILD_NAME > $BUILDER_DIR/scripts/app_build_$APP_ID.vdf
curl https://raw.githubusercontent.com/saiaku-gaming/jenkins-common/master/$DEPO_BUILD_NAME > $BUILDER_DIR/scripts/depot_build_$DEPOT_ID.vdf

sed -i "s/\$BUILD_VERSION/$BUILD_VERSION/g" $BUILDER_DIR/scripts/app_build_$APP_ID.vdf

if [ "$USE_LOCAL" = "true" ]; then
	sed -i 's,"setlive" "development","setlive" "local",g' $BUILDER_DIR/scripts/app_build_$APP_ID.vdf
	sed -i 's,"local" "","local" "/opt/steam-content",g' $BUILDER_DIR/scripts/app_build_$APP_ID.vdf
fi

#If below does not work, try installing support for 32-bit os.
#sudo apt-get install libc6:i386 libncurses5:i386 libstdc++6:i386

/bin/bash $BUILDER_DIR/builder_linux/steamcmd.sh +login $STEAM_USER $STEAM_PASSWORD +run_app_build $(pwd)/$BUILDER_DIR/scripts/app_build_$APP_ID.vdf +quit
