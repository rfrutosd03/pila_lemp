#!/bin/bash

echo "Iniciando aprovisionamiento del balanceador de carga..."

echo "Actualizando sistema..."
apt-get update
apt-get upgrade -y

echo "Instalando Nginx..."
apt-get install -y nginx

echo "Configurando Nginx como balanceador de carga..."
cat > /etc/nginx/sites-available/default <<'EOF'
upstream backend_servers {
    server 192.168.2.21:80;
    server 192.168.2.22:80;
}

server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://backend_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    access_log /var/log/nginx/balancer_access.log;
    error_log /var/log/nginx/balancer_error.log;
}
EOF

echo "Verificando configuracion de Nginx..."
nginx -t

echo "Reiniciando y habilitando Nginx..."
systemctl restart nginx
systemctl enable nginx

echo "Balanceador de carga configurado correctamente"