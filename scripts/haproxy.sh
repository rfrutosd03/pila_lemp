#!/bin/bash

set -e

echo "=========================================="
echo "=== [3/7] Configurando HAProxy        ==="
echo "=== (Balanceador de Base de Datos)    ==="
echo "=========================================="

sleep 7



# Instalar HAProxy
echo "[HAProxy] Instalando HAProxy..."
apt-get update -y
apt-get install -y haproxy

# Configurar HAProxy
echo "[HAProxy] Configurando balanceador de base de datos..."
cat > /etc/haproxy/haproxy.cfg << 'EOF'
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
    log global
    mode tcp
    option tcplog
    option dontlognull
    timeout connect 10s
    timeout client 1h
    timeout server 1h

frontend mariadb_frontend
    bind *:3306
    mode tcp
    default_backend mariadb_backend

backend mariadb_backend
    mode tcp
    balance roundrobin
    option tcp-check
    tcp-check connect
    server db1 10.0.4.20:3306 check inter 5s rise 2 fall 3
    server db2 10.0.4.30:3306 check inter 5s rise 2 fall 3

listen stats
    bind *:8080
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if TRUE
    stats auth admin:admin
EOF

# Iniciar HAProxy
echo "[HAProxy] Iniciando servicio..."
systemctl enable haproxy
systemctl restart haproxy

sleep 5
systemctl status haproxy --no-pager || true

echo ""
echo "✅ [HAProxy] Configurado correctamente"
echo "📊 Estadísticas: http://10.0.3.20:8080/stats"
echo "   Usuario: admin | Contraseña: admin"
echo "=========================================="