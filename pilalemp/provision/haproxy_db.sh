#!/usr/bin/env bash
set -euo pipefail

DB1_IP="${1}"

apt-get update
apt-get install -y haproxy

cat >/etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log local0
    maxconn 4096
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    timeout connect 5s
    timeout client  1m
    timeout server  1m

frontend mysql_front
    bind *:3306
    default_backend mysql_back

backend mysql_back
    balance roundrobin
    server db1 ${DB1_IP}:3306 check inter 2s fall 3 rise 2
EOF

systemctl enable haproxy
systemctl restart haproxy
