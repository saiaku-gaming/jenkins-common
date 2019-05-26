#!/bin/sh

set -x
set -e

sudo curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.6.1-x86_64.rpm

sudo rpm -vi filebeat-6.6.1-x86_64.rpm
sudo service filebeat stop || true

sudo mkdir -p /local/game/valhalla/Saved/Logs
sudo chmod -R 777 /local/game/valhalla/Saved

sudo tee /etc/filebeat/filebeat.yml <<'EOF'
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /local/game/valhalla/Saved/Logs/*.log
    exclude_files: ['.*backup.*']
    multiline.pattern: ^\[[0-9]{4}\.[0-9]{2}\.[0-9]{2}
    multiline.negate: true
    multiline.match: after
  - type: log
    enabled: true
    paths:
      - /var/log/messages
filebeat.config.modules:
  path: ${path.config}/modules.d/*.yml
  reload.enabled: false
setup.template.settings:
  index.number_of_shards: 1
output.logstash:
  hosts: ["logstash.valhalla-game.com:32044"]
processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
EOF

sudo chkconfig --add filebeat  || true
sudo chkconfig filebeat on || true
sudo nohup service filebeat start

