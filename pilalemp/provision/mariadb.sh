#!/usr/bin/env bash
set -euo pipefail

HAPROXY_IP="${1}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y mariadb-server

# Bind a la interfaz privada
sed -i 's/^#*\s*bind-address.*/bind-address = 10.10.10.50/' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl enable mariadb
systemctl restart mariadb

# Seguridad básica y usuario de app
mysql -u root <<'SQL'
CREATE DATABASE IF NOT EXISTS gestion_usuarios CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'appuser'@'10.10.10.%' IDENTIFIED BY 'appsecret';
GRANT ALL PRIVILEGES ON gestion_usuarios.* TO 'appuser'@'10.10.10.%';
FLUSH PRIVILEGES;
SQL

# Comprobación de conectividad desde HAProxy (opcional)
echo "MariaDB configurado. Conecta vía ${HAPROXY_IP}:3306"
