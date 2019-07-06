#!/bin/sh

set -e

BUILD_VERSION=$1
STORAGE_SERVER_SECRET=$2
RELEASE_VERSION=$3

pip install awscli --upgrade --user
PATH=~/.local/bin/:$PATH

export AWS_DEFAULT_REGION=eu-central-1
export AWS_DEFAULT_OUTPUT=json

delete_game_session_queues() {
	local FLEET_ARN="$1"
	local QUEUE_NAME=""
	local QUEUES="$(aws gamelift describe-game-session-queues)"
	local Q_SIZE="$(echo "$QUEUES" | jq '.GameSessionQueues | length')"
	local DESTINATION_ARN=""
	Q_SIZE=$(( $Q_SIZE - 1))

	for j in `seq 0 $Q_SIZE`; do
		DESTINATION_ARN="$(echo "$QUEUES" | jq  ".GameSessionQueues[$j].Destinations[0].DestinationArn" | sed 's/"//g')"
		if [ "$FLEET_ARN" = "$DESTINATION_ARN" ]; then
			QUEUE_NAME="$(echo "$QUEUES" | jq ".GameSessionQueues[$j].Name" | sed 's/"//g')"
			aws gamelift delete-game-session-queue --name "$QUEUE_NAME"
		fi
	done
}

echo "Removing old fleets..."

EXISTING_FLEETS=$(aws gamelift describe-fleet-attributes)

SIZE=$(echo $EXISTING_FLEETS | jq '.FleetAttributes | length')
SIZE=$(( $SIZE - 1 ))
FLEET_ARN=""
INSTANCES=0
STATUS=""
FLEET_ID=""
BUILD_ID=""

for i in `seq 0 $SIZE`; do
	FLEET_ARN=$(echo $EXISTING_FLEETS | jq ".FleetAttributes[$i].FleetArn" | sed 's/"//g')
	FLEET_ID=$(echo $EXISTING_FLEETS | jq ".FleetAttributes[$i].FleetId" | sed 's/"//g')
	INSTANCES=$(aws gamelift describe-instances --fleet-id $FLEET_ID | jq '.Instances | length')
	STATUS=$(echo "$EXISTING_FLEETS" | jq ".FleetAttributes[$i].Status" | sed 's/"//g')
	NAME=$(echo "$EXISTING_FLEETS" | jq ".FleetAttributes[$i].Name" | sed 's/"//g')
	if [ "$RELEASE_VERSION $BUILD_VERSION Fleet" = "$NAME" ]; then
		echo "ERROR: The current release version and build version combination already exists... ROBIN!"
		exit 1
	fi
	if [ ! -z "$(echo "$NAME" | grep "$RELEASE_VERSION")" ]; then
		if [ "$INSTANCES" = "0" -a "$STATUS" = "ACTIVE" ]; then
			delete_game_session_queues "$FLEET_ARN"
			aws gamelift delete-fleet --fleet-id "$FLEET_ID"
			BUILD_ID="$(echo "$EXISTING_FLEETS" | jq ".FleetAttributes[$i].BuildId" | sed 's/"//g')"
			aws gamelift delete-build --build-id "$BUILD_ID"
		fi
	fi
done

QUEUES=$(aws gamelift describe-game-session-queues)

Q_SIZE=$(echo $QUEUES | jq '.GameSessionQueues | length')
Q_SIZE=$(( $Q_SIZE - 1 ))
DESTINATION_ARN=""
FOUND_LINK=""
QUEUE_NAME=""

for i in `seq 0 $Q_SIZE`; do
	DESTINATION_ARN=$(echo $QUEUES | jq ".GameSessionQueues[$i].Destinations[0].DestinationArn" | sed 's/"//g')
	for j in `seq 0 $SIZE`; do
		FLEET_ARN=$(echo $EXISTING_FLEETS | jq ".FleetAttributes[$j].FleetArn" | sed 's/"//g')
		if [ "$DESTINATION_ARN" = "$FLEET_ARN" ]; then
			FOUND_LINK="true"
		fi
	done
	if [ -z $FOUND_LINK ]; then
		QUEUE_NAME=$(echo $QUEUES | jq ".GameSessionQueues[$i].Name" | sed 's/"//g')
		aws gamelift delete-game-session-queue --name $QUEUE_NAME
	fi
	FOUND_LINK=""
done

rm -rf *

mkdir downloaded-builds
wget --header="Authorization: $STORAGE_SERVER_SECRET" -O "LinuxServer$BUILD_VERSION$RELEASE_VERSION.zip" "https://binary-storage.valhalla-game.com/storage?path=valhalla-linux-server&name=LinuxServer$BUILD_VERSION$RELEASE_VERSION.zip"
unzip LinuxServer$BUILD_VERSION$RELEASE_VERSION.zip -d downloaded-builds/LinuxServer

curl https://raw.githubusercontent.com/saiaku-gaming/jenkins-common/master/gamelift-install.sh > downloaded-builds/LinuxServer/install.sh
chmod +x ./downloaded-builds/LinuxServer/install.sh

#pre create an empty saved logs file so that graylog can monitor the folder on system start.
mkdir -p ./downloaded-builds/LinuxServer/valhalla/Saved/Logs

chmod +x ./downloaded-builds/LinuxServer/valhalla/Binaries/Linux/valhallaServer

echo "Uploading build..."
OUTPUT="$(aws gamelift upload-build --name "$RELEASE_VERSION $BUILD_VERSION Build" --build-version $BUILD_VERSION$RELEASE_VERSION --build-root ./downloaded-builds/LinuxServer --operating-system AMAZON_LINUX --region "eu-central-1")"
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
FLEET_RESPONSE=$(aws gamelift create-fleet --name "$RELEASE_VERSION $BUILD_VERSION Fleet" --build-id "$BUILD_ID" --ec2-instance-type "c4.large" --ec2-inbound-permissions '[{"FromPort": 7777,"ToPort": 7787,"IpRange": "0.0.0.0/0","Protocol": "UDP"},{"FromPort": 8990,"ToPort": 9000,"IpRange": "0.0.0.0/0","Protocol": "TCP"}]' --runtime-configuration '{"ServerProcesses": [{"LaunchPath": "/local/game/valhalla/Binaries/Linux/valhallaServer", "Parameters": "-Log -GameLift -NOSTEAM", "ConcurrentExecutions": 10}], "MaxConcurrentGameSessionActivations": 10, "GameSessionActivationTimeoutSeconds": 1}')

FLEET_ARN=$(echo $FLEET_RESPONSE | jq .FleetAttributes.FleetArn | sed s/\"//g)
FLEET_ID=$(echo $FLEET_RESPONSE | jq .FleetAttributes.FleetId | sed s/\"//g)

echo "Fleet created!"
echo "Adding scaling policies"

aws gamelift put-scaling-policy --name "Scale up" --fleet-id "$FLEET_ID" --scaling-adjustment "1" --scaling-adjustment-type "ExactCapacity" --threshold "1" --comparison-operator "GreaterThanOrEqualToThreshold" --evaluation-periods "1" --metric-name "QueueDepth"

aws gamelift put-scaling-policy --name "Scale down" --fleet-id "$FLEET_ID" --scaling-adjustment "0" --scaling-adjustment-type "ExactCapacity" --threshold "1" --comparison-operator "LessThanThreshold" --evaluation-periods "60" --metric-name "ActiveGameSessions"

#RESPONSE=$(aws gamelift describe-game-session-queues)
#SIZE=$(echo $RESPONSE | jq '.GameSessionQueues | length')
#SIZE=$(( $SIZE - 1 ))

#echo "Deleting old queues"
#for i in `seq 0 $SIZE`; do
#	NAME=$(echo $RESPONSE | jq ".GameSessionQueues[$i].Name" | sed 's,",,g')
#	echo "Deleting queue $NAME..."
#	aws gamelift delete-game-session-queue --name $NAME
#done
#echo "Old queues deleted"

aws gamelift create-game-session-queue --name "DungeonQueue$BUILD_VERSION$RELEASE_VERSION" --destinations DestinationArn=$FLEET_ARN --timeout-in-seconds 600
echo "DungeonQueue Created"

exit 0
