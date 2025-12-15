#!/bin/bash

set -e

echo "=========================================="
echo "=== [1/7] Configurando Base de Datos 1 ==="
echo "=== (Nodo Principal Galera Cluster)    ==="
echo "=========================================="

sleep 5



# Instalar MariaDB Galera Cluster
echo "[DB1] Instalando MariaDB Galera Cluster..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client galera-4 rsync

# Detener MariaDB para configurar Galera
systemctl stop mariadb

# Configurar Galera Cluster
echo "[DB1] Configurando Galera Cluster..."
cat > /etc/mysql/mariadb.conf.d/60-galera.cnf << 'EOF'
[mysqld]
binlog_format=ROW
default-storage-engine=innodb
innodb_autoinc_lock_mode=2
bind-address=0.0.0.0

# Configuración Galera
wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so

wsrep_cluster_name="galera_cluster_ricardo"
wsrep_cluster_address="gcomm://10.0.4.20,10.0.4.30"

wsrep_sst_method=rsync

wsrep_node_address="10.0.4.20"
wsrep_node_name="db1"
EOF

# Inicializar cluster como nodo principal
echo "[DB1] Inicializando cluster Galera (nodo principal)..."
galera_new_cluster
sleep 15

systemctl status mariadb --no-pager || true

# Crear base de datos y usuarios
echo "[DB1] Creando base de datos y usuarios..."
mysql << 'EOSQL'
CREATE DATABASE IF NOT EXISTS lamp_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'ricardo'@'%' IDENTIFIED BY '1234';
GRANT ALL PRIVILEGES ON lamp_db.* TO 'ricardo'@'%';

CREATE USER IF NOT EXISTS 'haproxy'@'%' IDENTIFIED BY '';
GRANT USAGE ON *.* TO 'haproxy'@'%';

CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'root';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

FLUSH PRIVILEGES;

SELECT User, Host FROM mysql.user
  WHERE User IN ('ricardo', 'haproxy', 'root');
EOSQL

# Habilitar MariaDB al inicio
systemctl enable mariadb

# Verificar estado del cluster
echo "=========================================="
echo "=== Estado del Cluster Galera         ==="
echo "=========================================="
mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';" 2>/dev/null || true
mysql -e "SHOW STATUS LIKE 'wsrep_cluster_status';" 2>/dev/null || true

echo ""
echo "✅ [DB1] Base de datos 1 configurada correctamente"
echo "=========================================="