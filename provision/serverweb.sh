#!/bin/bash

echo "Iniciando aprovisionamiento del servidor web..."

echo "Actualizando sistema..."
apt-get update
apt-get upgrade -y

echo "Instalando Nginx y cliente NFS..."
apt-get install -y nginx nfs-common

echo "Creando directorio para montar NFS..."
mkdir -p /var/www/html
chown www-data:www-data /var/www/html

echo "Configurando montaje automatico de NFS..."
echo "192.168.3.23:/var/nfs/shared /var/www/html nfs defaults,_netdev 0 0" >> /etc/fstab

echo "Esperando servidor NFS..."
for i in {1..30}; do
    if showmount -e 192.168.3.23 >/dev/null 2>&1; then
        echo "Servidor NFS detectado"
        break
    fi
    echo "Intento $i/30..."
    sleep 2
done

echo "Montando directorio NFS..."
mount -a

echo "Configurando Nginx para PHP..."
cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        
        fastcgi_pass 192.168.3.23:9000;
        
        fastcgi_param SCRIPT_FILENAME /var/nfs/shared$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT /var/nfs/shared;
        
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    access_log /var/log/nginx/app_access.log;
    error_log /var/log/nginx/app_error.log;
}
EOF

echo "Verificando configuracion de Nginx..."
nginx -t

echo "Reiniciando Nginx..."
systemctl restart nginx
systemctl enable nginx

echo "Servidor web configurado correctamente"