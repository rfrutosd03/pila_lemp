#!/bin/bash

set -e

echo "=========================================="
echo "=== [7/7] Configurando Balanceador    ==="
echo "=== (Punto de entrada HTTP)           ==="
echo "=========================================="

sleep 5



# Actualizar e instalar NGINX
echo "[Balanceador] Instalando NGINX..."
apt-get update -y
apt-get install -y nginx

# Configurar balanceador NGINX
echo "[Balanceador] Configurando balanceo de carga..."
cat > /etc/nginx/sites-available/balancer << 'EOF'
upstream web_pool {
    server 10.0.2.20:80 max_fails=3 fail_timeout=30s;
    server 10.0.2.30:80 max_fails=3 fail_timeout=30s;
}

server {
    listen 80 default_server;
    server_name _;

    access_log /var/log/nginx/balancer_access.log;
    error_log  /var/log/nginx/balancer_error.log;

    location / {
        proxy_pass http://web_pool;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /healthcheck {
        access_log off;
        add_header Content-Type text/plain;
        return 200 "Balanceador OK\n";
    }
}
EOF

# Activar configuración
ln -sf /etc/nginx/sites-available/balancer /etc/nginx/sites-enabled/balancer
rm -f /etc/nginx/sites-enabled/default

# Iniciar NGINX
echo "[Balanceador] Iniciando NGINX..."
nginx -t
systemctl restart nginx
systemctl enable nginx

echo ""
echo "=========================================="
echo "✅ INFRAESTRUCTURA COMPLETA DESPLEGADA"
echo "=========================================="
echo ""
echo "🎯 Acceso a la aplicación:"
echo "   http://localhost:8080"
echo ""
echo "📊 Panel HAProxy:"
echo "   http://localhost:8080 (desde VM HAProxy)"
echo "   Usuario: admin | Contraseña: admin"
echo ""
echo "🏗️  Arquitectura desplegada:"
echo "   [1] DB1 (10.0.4.20) - Galera Primary"
echo "   [2] DB2 (10.0.4.30) - Galera Secondary"
echo "   [3] HAProxy (10.0.3.20) - DB Load Balancer"
echo "   [4] NFS (10.0.2.40) - Files + PHP-FPM"
echo "   [5] Web1 (10.0.2.20) - Web Server"
echo "   [6] Web2 (10.0.2.30) - Web Server"
echo "   [7] Balanceador (10.0.2.10) - HTTP Load Balancer"
echo ""
echo "=========================================="