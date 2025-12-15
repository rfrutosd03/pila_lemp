##!/bin/bash

echo "Iniciando aprovisionamiento del proxy de base de datos..."

echo "Actualizando sistema..."
apt-get update
apt-get upgrade -y

echo "Instalando HAProxy..."
apt-get install -y haproxy

echo "Configurando HAProxy para MariaDB..."
cat > /etc/haproxy/haproxy.cfg <<'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

listen mysql-cluster
    bind *:3306
    mode tcp
    option mysql-check user haproxy
    balance roundrobin
    server mariadb1 192.168.5.40:3306 check

listen stats
    bind *:8080
    mode http
    stats enable
    stats uri /stats
    stats refresh 5s
    stats realm HAProxy\ Statistics
    stats auth admin:admin123
EOF

echo "Verificando configuracion de HAProxy..."
haproxy -c -f /etc/haproxy/haproxy.cfg

echo "Habilitando y arrancando HAProxy..."
systemctl enable haproxy
systemctl restart haproxy

echo "Proxy de base de datos configurado correctamente"
echo "Estadisticas disponibles en http://IP:8080/stats (admin/admin123)"