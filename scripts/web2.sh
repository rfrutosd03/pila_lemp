#!/bin/bash

set -e

echo "=========================================="
echo "=== [6/7] Configurando Servidor Web 2 ==="
echo "=========================================="

sleep 5

# ============================================
# CONFIGURACIÓN CRÍTICA DE RED
# ============================================
echo "[WEB2] Configurando interfaces de red..."

# Identificar y configurar la interfaz correcta para 10.0.2.30
for iface in /sys/class/net/eth*; do
    iface_name=$(basename $iface)
    
    # Levantar la interfaz si está caída
    ip link set $iface_name up 2>/dev/null || true
    sleep 1
    
    # Verificar si esta interfaz tiene la IP 10.0.2.30
    if ip addr show $iface_name | grep -q "10.0.2.30"; then
        echo "[WEB2] ✓ Interfaz $iface_name tiene IP 10.0.2.30"
        WEB2_INTERFACE=$iface_name
    fi
done

# Si no encontramos la interfaz con la IP, la configuramos manualmente
if [ -z "$WEB2_INTERFACE" ]; then
    echo "[WEB2] ⚠ No se encontró interfaz con 10.0.2.30, configurando manualmente..."
    
    for iface in eth1 eth2 eth3; do
        if ip link show $iface >/dev/null 2>&1; then
            current_ip=$(ip addr show $iface | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
            if [ -z "$current_ip" ] || [ "$current_ip" == "10.0.2.30" ]; then
                ip addr flush dev $iface
                ip addr add 10.0.2.30/24 dev $iface
                ip link set $iface up
                echo "[WEB2] ✓ Configurada interfaz $iface con 10.0.2.30/24"
                WEB2_INTERFACE=$iface
                break
            fi
        fi
    done
fi

# Mostrar configuración de red
echo "[WEB2] Configuración de red actual:"
ip addr show | grep -E "(eth|inet )"
echo ""
ip route show
echo ""

# Asegurar que tenemos una ruta a la red 10.0.2.0/24
if ! ip route show | grep -q "10.0.2.0/24"; then
    echo "[WEB2] Añadiendo ruta a 10.0.2.0/24..."
    ip route add 10.0.2.0/24 dev ${WEB2_INTERFACE:-eth1} 2>/dev/null || true
fi

# ============================================
# VERIFICAR CONECTIVIDAD CON NFS
# ============================================
echo "[WEB2] Verificando conectividad con servidor NFS (10.0.2.40)..."

MAX_ATTEMPTS=60
ATTEMPT=0
NFS_REACHABLE=0

while [ ${ATTEMPT} -lt ${MAX_ATTEMPTS} ]; do
  # Intentar ping
  if ping -c 1 -W 2 10.0.2.40 >/dev/null 2>&1; then
    echo "[WEB2] ✓ Conectividad con NFS establecida (intento $((ATTEMPT+1)))"
    NFS_REACHABLE=1
    break
  fi
  
  ATTEMPT=$((ATTEMPT + 1))
  
  # Cada 10 intentos, mostrar diagnóstico
  if [ $((ATTEMPT % 10)) -eq 0 ]; then
    echo "[WEB2] Intento ${ATTEMPT}/${MAX_ATTEMPTS} - Diagnóstico:"
    echo "  - Interfaces activas:"
    ip link show | grep -E "^[0-9]" | grep "UP"
    echo "  - IPs configuradas:"
    ip addr | grep "inet " | grep -v "127.0.0.1"
    echo "  - Rutas:"
    ip route show
    echo "  - Intentando levantar interfaces..."
    for iface in eth1 eth2; do
      ip link set $iface up 2>/dev/null || true
    done
  fi
  
  sleep 5
done

if [ $NFS_REACHABLE -eq 0 ]; then
  echo "[WEB2] ❌ ERROR CRÍTICO: No se puede alcanzar el servidor NFS"
  echo ""
  echo "[WEB2] Información de diagnóstico completa:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Interfaces de red:"
  ip addr
  echo ""
  echo "Tabla de rutas:"
  ip route
  echo ""
  echo "Estado de interfaces:"
  ip link
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 1
fi

# ============================================
# INSTALAR PAQUETES
# ============================================
echo "[WEB2] Instalando NGINX y cliente NFS..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx nfs-common rpcbind

# ============================================
# CONFIGURAR MONTAJE NFS
# ============================================
mkdir -p /var/www/html/webapp

# Verificar servicios RPC en el servidor NFS
echo "[WEB2] Verificando servicios NFS disponibles..."
showmount -e 10.0.2.40 2>/dev/null || {
    echo "[WEB2] ⚠ No se pueden listar exportaciones NFS, esperando..."
    sleep 10
    showmount -e 10.0.2.40 2>/dev/null || echo "[WEB2] ⚠ Aún no disponibles las exportaciones"
}

# Esperar para asegurar que NFS está completamente listo
echo "[WEB2] Esperando a que NFS esté completamente disponible..."
sleep 15

# Intentar montar NFS con múltiples intentos
echo "[WEB2] Montando sistema de archivos NFS..."
MOUNT_ATTEMPTS=5
MOUNTED=0

for i in $(seq 1 $MOUNT_ATTEMPTS); do
    echo "[WEB2] Intento de montaje $i/$MOUNT_ATTEMPTS..."
    
    if mount -t nfs -o soft,timeo=30,retrans=3,retry=5 10.0.2.40:/var/www/html/webapp /var/www/html/webapp 2>/dev/null; then
        echo "[WEB2] ✓ NFS montado correctamente"
        MOUNTED=1
        break
    else
        echo "[WEB2] ⚠ Fallo en intento $i, esperando 10s..."
        sleep 10
    fi
done

if [ $MOUNTED -eq 0 ]; then
    echo "[WEB2] ❌ ERROR: No se pudo montar NFS después de $MOUNT_ATTEMPTS intentos"
    echo ""
    echo "[WEB2] Diagnóstico de NFS:"
    rpcinfo -p 10.0.2.40 2>/dev/null || echo "  - No se puede contactar con RPC"
    showmount -e 10.0.2.40 2>/dev/null || echo "  - No se pueden ver exportaciones"
    echo ""
    echo "[WEB2] Logs del sistema:"
    dmesg | tail -20
    exit 1
fi

# Añadir a fstab
if ! grep -q "10.0.2.40:/var/www/html/webapp" /etc/fstab; then
    echo "10.0.2.40:/var/www/html/webapp /var/www/html/webapp nfs soft,timeo=30,retrans=3,retry=5 0 0" >> /etc/fstab
fi

# Verificar contenido del montaje
echo "[WEB2] Verificando contenido del montaje NFS..."
if ls -la /var/www/html/webapp/ >/dev/null 2>&1; then
    echo "[WEB2] ✓ Contenido NFS accesible:"
    ls -lh /var/www/html/webapp/ | head -5
else
    echo "[WEB2] ⚠ No se puede acceder al contenido NFS"
fi

# ============================================
# CONFIGURAR NGINX
# ============================================
echo "[WEB2] Configurando NGINX..."
cat > /etc/nginx/sites-available/webapp << 'EOF'
server {
    listen 80;
    server_name _;

    root /var/www/html/webapp;
    index index.php index.html index.htm;

    access_log /var/log/nginx/web2_access.log;
    error_log /var/log/nginx/web2_error.log;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass 10.0.2.40:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        
        # Timeouts más largos
        fastcgi_connect_timeout 60s;
        fastcgi_send_timeout 60s;
        fastcgi_read_timeout 60s;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Activar configuración
ln -sf /etc/nginx/sites-available/webapp /etc/nginx/sites-enabled/webapp
rm -f /etc/nginx/sites-enabled/default

# Verificar configuración de NGINX
echo "[WEB2] Verificando configuración de NGINX..."
if nginx -t 2>&1; then
    echo "[WEB2] ✓ Configuración de NGINX válida"
else
    echo "[WEB2] ❌ ERROR en configuración de NGINX"
    exit 1
fi

# Iniciar NGINX
echo "[WEB2] Iniciando NGINX..."
systemctl restart nginx
systemctl enable nginx

# Verificar que NGINX está corriendo
sleep 2
if systemctl is-active --quiet nginx; then
    echo "[WEB2] ✓ NGINX está corriendo"
else
    echo "[WEB2] ⚠ NGINX no está activo"
    systemctl status nginx --no-pager
fi

echo ""
echo "✅ [WEB2] Servidor Web 2 configurado correctamente"
echo "🌐 Sirviendo desde: 10.0.2.30"
echo "📁 NFS montado desde: 10.0.2.40:/var/www/html/webapp"
echo "🔗 Backend PHP-FPM: 10.0.2.40:9000"
echo "=========================================="