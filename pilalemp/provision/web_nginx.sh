#!/usr/bin/env bash
set -euo pipefail

NFS_IP="${1}"
APP_DIR="/var/www/app"

apt-get update
apt-get install -y nginx nfs-common

mkdir -p "${APP_DIR}"
echo "${NFS_IP}:/srv/app ${APP_DIR} nfs defaults,_netdev 0 0" >> /etc/fstab
mount -a

# Permisos básicos
chown -R www-data:www-data "${APP_DIR}"

cat >/etc/nginx/sites-available/app.conf <<'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/app/public;

    access_log /var/log/nginx/web_access.log;
    error_log  /var/log/nginx/web_error.log;

    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        # PHP-FPM remoto en serverNFS
        fastcgi_pass 10.10.10.30:9000;
    }

    location ~* \.(css|js|png|jpg|jpeg|gif|svg|ico)$ {
        expires 7d;
        access_log off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/app.conf /etc/nginx/sites-enabled/app.conf
rm -f /etc/nginx/sites-enabled/default

systemctl enable nginx
systemctl restart nginx
