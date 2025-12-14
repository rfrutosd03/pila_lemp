#!/usr/bin/env bash
set -euo pipefail

WEB1_IP="${1}"
WEB2_IP="${2}"
APP_DIR="/srv/app"

apt-get update
apt-get install -y nfs-kernel-server php-fpm php-mysql php-cli php-curl php-xml php-mbstring git

mkdir -p "${APP_DIR}"
chown -R www-data:www-data "${APP_DIR}"

# App de ejemplo (puedes sustituir por tu repo)
if [ ! -d "${APP_DIR}/public" ]; then
  mkdir -p "${APP_DIR}/public"
  cat >"${APP_DIR}/public/index.php" <<'PHP'
<?php
echo "Hola desde la app Gestión de Usuarios (LEMP) - " . date('c') . "\n";
phpinfo();
PHP
fi

# Export NFS
echo "${APP_DIR} ${WEB1_IP}(rw,sync,no_subtree_check) ${WEB2_IP}(rw,sync,no_subtree_check)" > /etc/exports
exportfs -ra
systemctl enable nfs-server
systemctl restart nfs-server

# Configurar PHP-FPM en TCP
sed -i 's|^listen = .*|listen = 0.0.0.0:9000|' /etc/php/*/fpm/pool.d/www.conf
sed -i 's|^;listen.allowed_clients =.*|listen.allowed_clients = 10.10.10.21,10.10.10.22|' /etc/php/*/fpm/pool.d/www.conf
sed -i 's|^;clear_env = yes|clear_env = no|' /etc/php/*/fpm/pool.d/www.conf

systemctl enable php*-fpm
systemctl restart php*-fpm
