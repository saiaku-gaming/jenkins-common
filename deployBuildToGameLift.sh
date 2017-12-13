#!/bin/sh

set -e

cd /home/valhalla

rsync -az --delete jenkins@valhalla-game.com:/home/valhalla/builds/$1/LinuxServer ./LinuxServer

echo "Uploading build..."
OUTPUT="$(aws gamelift upload-build --name "$1 Build" --build-version $1 --build-root ./LinuxServer --operating-system AMAZON_LINUX --region "eu-central-1")"
BUILD_ID="$(echo $OUTPUT | tail -n 1 | sed 's/^.*Build ID: //')"
echo "Build uploaded with id: $BUILD_ID"
COUNT=0
READY=""

while [ "$READY" != "READY" ] && [ $COUNT -ne 60 ]; do
	echo "Checking if build is ready..."
	sleep 1
	READY=$(aws gamelift describe-build --build-id "$BUILD_ID" | jq .Build.Status | sed s/\"//g)
	COUNT=`expr $COUNT + 1`
done

echo "Creating fleet..."
aws gamelift create-fleet --name "$2 Fleet" --build-id "$BUILD_ID" --ec2-instance-type "c4.large" --server-launch-path "/local/game/valhalla/Binaries/Linux/valhallaServer" --server-launch-parameters "-Log -GameLift" --ec2-inbound-permissions '[{"FromPort": 7777,"ToPort": 7777,"IpRange": "0.0.0.0/0","Protocol": "UDP"},{"FromPort": 8990,"ToPort": 8990,"IpRange": "0.0.0.0/0","Protocol": "TCP"}]'
echo "Fleet created!"
exit 0
