#!/bin/sh

set -x
set -e

sudo curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.6.1-x86_64.rpm
sudo rpm -vi filebeat-6.6.1-x86_64.rpm

sudo mkdir -p /local/game/valhalla/Saved/Logs
sudo chmod -R 777 /local/game/valhalla/Saved

sudo tee /etc/filebeat/filebeat.yml <<EOF
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/messages
      - /local/game/valhalla/Saved/Logs/*.log
    exclude_files: ['.*backup.*']
    #multiline.pattern: ^\[
    #multiline.negate: false
    #multiline.match: after
filebeat.config.modules:
  path: ${path.config}/modules.d/*.yml
  reload.enabled: false
setup.template.settings:
  index.number_of_shards: 1
#tags: ["service-X", "web-tier"]
#fields:
#  env: staging
output.logstash:
  hosts: ["logstash.logstash.valhalla-game.com:5044"]
  #ssl.certificate_authorities: ["/etc/pki/root/ca.pem"]
  #ssl.certificate: "/etc/pki/client/cert.pem"
  #ssl.key: "/etc/pki/client/cert.key"
processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
EOF

sudo service filebeat stop || true
sudo service filebeat start || true
