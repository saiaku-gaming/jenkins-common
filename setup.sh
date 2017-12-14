#!/bin/sh

set -e

JENKINS_USER=$1
VALHALLA_HOME="/home/valhalla"

if [ "$(id -u)" != "0" ]; then
	echo "Only root can run this script!"
	exit 1
fi

if [ "$(pwd)" != "$VALHALLA_HOME/jenkins-common" ]; then
	echo "The scripts have to be located and run from here: $VALHALLA_HOME/jenkins-common"
	exit 1
fi

if [ ! -f ../steamworks_sdk.zip ]; then
	echo "Unable to find steamworks_sdk.zip!"
	echo "Download here: https://partner.steamgames.com/downloads/steamworks_sdk.zip"
	exit 1
fi

if [ -z $JENKINS_USER ]; then
	echo "You have to provide the jenkins user"
	exit 1
fi

useradd -md /home/valhalla valhalla
chmod g+w /home/valhalla

#install dependencies

#add latest docker version, called docker-ce
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update

apt-get install -y openjdk-8-jdk maven python-pip build-essentail steamcmd jq docker-ce

pip install --upgrade pip

#install awscli for gamelift uploads
su - $JENKINS_USER "pip install awscli --upgrade --user"

mkdir downloaded-builds
chown $JENKINS_USER:$JENKINS_USER downloaded-builds

#install steamworks sdk for steam uploads
cd ..

unzip steamworks_sdk.zip
#rm steamworks_sdk.zip

rm sdk/tools/ContentBuilder/scripts/*

ln -s ../../../../jenkins-common/app_build_763550.vdf sdk/tools/ContentBuilder/scripts/app_build_763550.vdf
ln -s ../../../../jenkins-common/depot_build_763551.vdf sdk/tools/ContentBuilder/scripts/depot_build_763551.vdf

mkdir sdk/tools/ContentBuilder/content/windows_content

chmod +x sdk/tools/linux/setup.sh

set +e

#calls setup twice since it usualy dies on the first try... steam thats why!
bash sdk/tools/linux/setup.sh --target=amd64 --debug --auto-update
bash sdk/tools/linux/setup.sh --target=amd64 --debug --auto-update

set -e

chmod +x sdk/tools/ContentBuilder/builder_linux/steamcmd.sh
chmod +x sdk/tools/ContentBuilder/builder_linux/linux32/steamcmd

sdk/tools/ContentBuilder/builder_linux/steamcmd.sh +quit

cd ..
chown -R valhalla:valhalla $VALHALLA_HOME

echo "Done"
