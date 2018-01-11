#!/bin/sh

set -e

cd /home/valhalla

rsync -az --delete jenkins@valhalla-game.com:/home/valhalla/builds/$1/LinuxServer/ ./downloaded-builds/LinuxServer
cp ./jenkins-common/gamelift-install.sh ./downloaded-builds/LinuxServer/install.sh

#pre create an empty saved logs file so that graylog can monitor the folder on system start.
mkdir -p ./downloaded-builds/LinuxServer/valhalla/Saved/Logs

echo "Uploading build..."
OUTPUT="$(/home/jenkins/.local/bin/aws gamelift upload-build --name "$1 Build" --build-version $1 --build-root ./downloaded-builds/LinuxServer --operating-system AMAZON_LINUX --region "eu-central-1")"
BUILD_ID="$(echo $OUTPUT | tail -n 1 | sed 's/^.*Build ID: //')"
echo "Build uploaded with id: $BUILD_ID"
COUNT=0
READY=""

while [ "$READY" != "READY" ] && [ $COUNT -ne 60 ]; do
	echo "Checking if build is ready..."
	sleep 1
	READY=$(/home/jenkins/.local/bin/aws gamelift describe-build --build-id "$BUILD_ID" | jq .Build.Status | sed s/\"//g)
	COUNT=`expr $COUNT + 1`
done

echo "Creating fleet..."
FLEET_RESPONSE=$(/home/jenkins/.local/bin/aws gamelift create-fleet --name "$3 Fleet" --build-id "$BUILD_ID" --ec2-instance-type "c4.large" --ec2-inbound-permissions '[{"FromPort": 7777,"ToPort": 7787,"IpRange": "0.0.0.0/0","Protocol": "UDP"},{"FromPort": 8990,"ToPort": 9000,"IpRange": "0.0.0.0/0","Protocol": "TCP"}]' --runtime-configuration '{"ServerProcesses": [{"LaunchPath": "/local/game/valhalla/Binaries/Linux/valhallaServer", "Parameters": "-Log -GameLift", "ConcurrentExecutions": 10}], "MaxConcurrentGameSessionActivations": 10, "GameSessionActivationTimeoutSeconds": 1}')

FLEET_ARN=$(echo $FLEET_RESPONSE | jq .FleetAttributes.FleetArn | sed s/\"//g)
FLEET_ID=$(echo $FLEET_RESPONSE | jq .FleetAttributes.FleetId | sed s/\"//g)

echo "Fleet created!"
echo "Adding scaling policies"

/home/jenkins/.local/bin/aws gamelift put-scaling-policy --name "Scale down" --fleet-id "$FLEET_ID" --scaling-adjustment "-1" --scaling-adjustment-type "ChangeInCapacity" --threshold "1" --comparison-operator "GreaterThanOrEqualToThreshold" --evaluation-periods "20" --metric-name "IdleInstances"

/home/jenkins/.local/bin/aws gamelift put-scaling-policy --name "Scale up" --fleet-id "$FLEET_ID" --scaling-adjustment "1" --scaling-adjustment-type "ExactCapacity" --threshold "1" --comparison-operator "GreaterThanOrEqualToThreshold" --evaluation-periods "1" --metric-name "QueueDepth"

RESPONSE=$(/home/jenkins/.local/bin/aws gamelift describe-game-session-queues)
SIZE=$(echo $RESPONSE | jq '.GameSessionQueues | length')
SIZE=$(( $SIZE - 1 ))

echo "Deleting old queues"
for i in `seq 0 $SIZE`; do
	NAME=$(echo $RESPONSE | jq ".GameSessionQueues[$i].Name" | sed 's,",,g')
	echo "Deleting queue $NAME..."
	/home/jenkins/.local/bin/aws gamelift delete-game-session-queue --name $NAME
done
echo "Old queues deleted"

/home/jenkins/.local/bin/aws gamelift create-game-session-queue --name "DungeonQueue$1" --destinations DestinationArn=$FLEET_ARN --timeout-in-seconds 600
echo "DungeonQueue Created"

exit 0
