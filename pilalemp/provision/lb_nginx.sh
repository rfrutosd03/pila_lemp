#!/usr/bin/env bash
set -euo pipefail

WEB1_IP="${1}"
WEB2_IP="${2}"

apt-get update
apt-get install -y nginx

cat >/etc/nginx/nginx.conf <<'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
events { worker_connections 1024; }
http {
  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  keepalive_timeout 65;
  types_hash_max_size 2048;
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  include /etc/nginx/conf.d/*.conf;
  include /etc/nginx/sites-enabled/*;
}
EOF

cat >/etc/nginx/conf.d/upstreams.conf <<EOF
upstream app_backend {
    server ${WEB1_IP}:80 max_fails=3 fail_timeout=10s;
    server ${WEB2_IP}:80 max_fails=3 fail_timeout=10s;
}
EOF

cat >/etc/nginx/sites-available/app.conf <<'EOF'
server {
    listen 80;
    server_name _;
    access_log /var/log/nginx/lb_access.log;
    error_log  /var/log/nginx/lb_error.log;

    location / {
        proxy_pass http://app_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Salud
    location /healthz {
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}
EOF

ln -sf /etc/nginx/sites-available/app.conf /etc/nginx/sites-enabled/app.conf
rm -f /etc/nginx/sites-enabled/default

systemctl enable nginx
systemctl restart nginx
