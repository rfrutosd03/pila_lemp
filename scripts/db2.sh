#!/bin/bash

set -e

echo "=========================================="
echo "=== [2/7] Configurando Base de Datos 2 ==="
echo "=== (Nodo Secundario Galera Cluster)   ==="
echo "=========================================="

sleep 10



# Instalar MariaDB Galera Cluster
echo "[DB2] Instalando MariaDB Galera Cluster..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client galera-4 rsync

# Detener MariaDB para configurar Galera
systemctl stop mariadb

# Configurar Galera Cluster
echo "[DB2] Configurando Galera Cluster..."
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

wsrep_node_address="10.0.4.30"
wsrep_node_name="db2"
EOF

# Iniciar MariaDB y unirse al cluster
echo "[DB2] Uniéndose al cluster Galera existente..."
systemctl start mariadb
sleep 15

systemctl status mariadb --no-pager || true
systemctl enable mariadb

# Verificar estado del cluster
echo "=========================================="
echo "=== Estado del Cluster Galera         ==="
echo "=========================================="
mysql -e "SHOW STATUS LIKE 'wsrep_%';" | grep -E "(wsrep_cluster_size|wsrep_cluster_status|wsrep_ready|wsrep_connected)" || true

echo ""
echo "✅ [DB2] Base de datos 2 configurada correctamente"
echo "=========================================="