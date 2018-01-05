#!/bin/sh

set -x
set -e

sudo wget https://github.com/Graylog2/collector-sidecar/releases/download/0.1.4/collector-sidecar-0.1.4-1.x86_64.rpm
sudo rpm -i collector-sidecar-0.1.4-1.x86_64.rpm

sudo graylog-collector-sidecar -service install
sudo mkdir -p /etc/graylog/collector-sidecar
sudo tee -a /etc/graylog/collector-sidecar/collector_sidecar.yml <<EOF
server_url: https://graylog.valhalla-game.com/api/
update_interval: 10
tls_skip_verify: false
send_status: true
list_log_files:
  - /var/log
  - /local/game/valhalla/Saved/Logs
node_id: graylog-collector-sidecar
collector_id: file:/etc/graylog/collector-sidecar/collector-id
cache_path: /var/cache/graylog/collector-sidecar
log_path: /var/log/graylog/collector-sidecar
log_rotation_time: 86400
log_max_age: 604800
tags:
  - gamelift
backends:
  - name: nxlog
    enabled: false
    binary_path: /usr/bin/nxlog
    configuration_path: /etc/graylog/collector-sidecar/generated/nxlog.conf
  - name: filebeat
    enabled: true
    binary_path: /usr/bin/filebeat
    configuration_path: /etc/graylog/collector-sidecar/generated/filebeat.yml
EOF

sudo service collector-sidecar stop || true
sudo service collector-sidecar start || true
