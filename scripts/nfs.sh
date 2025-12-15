#!/bin/bash

set -e

echo "=========================================="
echo "=== [4/7] Configurando Servidor NFS   ==="
echo "=== (Archivos compartidos + PHP-FPM)  ==="
echo "=========================================="

sleep 5

# ============================================
# CONFIGURACIÓN CRÍTICA DE RED
# ============================================
echo "[NFS] Configurando interfaces de red..."

# Identificar y configurar la interfaz correcta para 10.0.2.40
for iface in /sys/class/net/eth*; do
    iface_name=$(basename $iface)
    
    # Levantar la interfaz si está caída
    ip link set $iface_name up 2>/dev/null || true
    sleep 1
    
    # Verificar si esta interfaz tiene la IP 10.0.2.40
    if ip addr show $iface_name | grep -q "10.0.2.40"; then
        echo "[NFS] ✓ Interfaz $iface_name tiene IP 10.0.2.40"
        NFS_INTERFACE=$iface_name
    fi
done

# Si no encontramos la interfaz con la IP, la configuramos manualmente
if [ -z "$NFS_INTERFACE" ]; then
    echo "[NFS] ⚠ No se encontró interfaz con 10.0.2.40, configurando manualmente..."
    
    # Buscar la interfaz eth que no tiene IP asignada
    for iface in eth1 eth2 eth3; do
        if ip link show $iface >/dev/null 2>&1; then
            current_ip=$(ip addr show $iface | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
            if [ -z "$current_ip" ] || [ "$current_ip" == "10.0.2.40" ]; then
                ip addr flush dev $iface
                ip addr add 10.0.2.40/24 dev $iface
                ip link set $iface up
                echo "[NFS] ✓ Configurada interfaz $iface con 10.0.2.40/24"
                NFS_INTERFACE=$iface
                break
            fi
        fi
    done
fi

# Mostrar configuración de red
echo "[NFS] Configuración de red actual:"
ip addr show | grep -E "(eth|inet )"
echo ""
ip route show
echo ""

# Verificar que podemos hacer ping a nosotros mismos
echo "[NFS] Verificando interfaz local..."
if ping -c 1 -W 2 10.0.2.40 >/dev/null 2>&1; then
    echo "[NFS] ✓ Ping a 10.0.2.40 exitoso"
else
    echo "[NFS] ❌ ERROR: No se puede hacer ping a la propia IP"
    echo "[NFS] Configuración de red:"
    ip addr
    ip route
fi

# ============================================
# INSTALACIÓN DE PAQUETES
# ============================================
echo "[NFS] Instalando paquetes..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git nfs-kernel-server rpcbind \
    php-fpm php-mysql php-curl php-gd php-mbstring \
    php-xml php-xmlrpc php-soap php-intl php-zip \
    netcat-openbsd net-tools iptables

# ============================================
# CONFIGURACIÓN DE FIREWALL
# ============================================
echo "[NFS] Configurando firewall (permitir todo en red interna)..."

# Limpiar reglas existentes
iptables -F
iptables -X

# Política por defecto ACCEPT
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Permitir todo el tráfico en loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Permitir todo desde la red 10.0.2.0/24
iptables -A INPUT -s 10.0.2.0/24 -j ACCEPT
iptables -A OUTPUT -d 10.0.2.0/24 -j ACCEPT

# Permitir tráfico establecido
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

echo "[NFS] ✓ Firewall configurado"

# ============================================
# CONFIGURACIÓN DE NFS
# ============================================
echo "[NFS] Configurando directorio compartido..."
mkdir -p /var/www/html/webapp
chown -R www-data:www-data /var/www/html/webapp
chmod -R 755 /var/www/html/webapp

# Configurar exportaciones NFS
cat > /etc/exports << 'EOF'
/var/www/html/webapp 10.0.2.0/24(rw,sync,no_subtree_check,no_root_squash,anonuid=33,anongid=33,insecure)
EOF

# Asegurar que RPC bind está corriendo
systemctl enable rpcbind
systemctl start rpcbind
sleep 2

# Activar y reiniciar NFS
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server
sleep 3

# Aplicar exportaciones
exportfs -ra
sleep 2

# Verificar exportaciones
echo "[NFS] Exportaciones NFS activas:"
exportfs -v
echo ""

# Verificar servicios RPC
echo "[NFS] Servicios RPC activos:"
rpcinfo -p | grep -E "(portmapper|nfs|mountd)" || true
echo ""

echo "[NFS] ✓ Servidor NFS configurado"

# ============================================
# CONFIGURACIÓN PHP-FPM
# ============================================
echo "[NFS] Configurando PHP-FPM..."
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_FPM_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"

# Backup de configuración original
cp ${PHP_FPM_CONF} ${PHP_FPM_CONF}.backup

# Configurar PHP-FPM para escuchar en 0.0.0.0:9000
sed -i 's|listen = /run/php/php.*-fpm.sock|listen = 0.0.0.0:9000|' ${PHP_FPM_CONF}
sed -i 's|;listen.allowed_clients.*|listen.allowed_clients = 10.0.2.0/24|' ${PHP_FPM_CONF}

# Configurar usuario y permisos
sed -i 's|^user = .*|user = www-data|' ${PHP_FPM_CONF}
sed -i 's|^group = .*|group = www-data|' ${PHP_FPM_CONF}

# Reiniciar PHP-FPM
systemctl restart php${PHP_VERSION}-fpm
systemctl enable php${PHP_VERSION}-fpm
sleep 2

echo "[NFS] Verificando PHP-FPM en puerto 9000:"
netstat -tlnp | grep 9000 || echo "⚠ PHP-FPM no está escuchando en 9000"
echo ""

# ============================================
# ESPERAR BASE DE DATOS
# ============================================
echo "[NFS] Esperando conexión a base de datos (HAProxy)..."
MAX_ATTEMPTS=60
ATTEMPT=0
while [ ${ATTEMPT} -lt ${MAX_ATTEMPTS} ]; do
  if nc -z 10.0.3.20 3306 2>/dev/null; then
    echo "[NFS] ✓ Base de datos disponible"
    break
  fi
  ATTEMPT=$((ATTEMPT + 1))
  echo -n "."
  sleep 5
done

if [ ${ATTEMPT} -ge ${MAX_ATTEMPTS} ]; then
  echo ""
  echo "⚠ Advertencia: No se pudo conectar a la base de datos"
fi

# ============================================
# DESCARGAR APLICACIÓN
# ============================================
echo "[NFS] Descargando aplicación web..."
rm -rf /var/www/html/webapp/*
rm -rf /tmp/lamp

git clone https://github.com/josejuansanchez/iaw-practica-lamp.git /tmp/lamp
cp -r /tmp/lamp/src/* /var/www/html/webapp/

# Crear configuración de base de datos
cat > /var/www/html/webapp/config.php << 'EOF'
<?php
$mysqli = new mysqli("10.0.3.20", "ricardo", "1234", "lamp_db");
if ($mysqli->connect_error) {
    die("Error de conexión: " . $mysqli->connect_error);
}
$mysqli->set_charset("utf8mb4");
?>
EOF

# Establecer permisos
chown -R www-data:www-data /var/www/html/webapp
chmod -R 755 /var/www/html/webapp
find /var/www/html/webapp -type f -exec chmod 644 {} \;
find /var/www/html/webapp -type d -exec chmod 755 {} \;

rm -rf /tmp/lamp

echo ""
echo "✅ [NFS] Servidor NFS y PHP-FPM configurados correctamente"
echo "📁 Archivos compartidos: /var/www/html/webapp"
echo "🌐 IP en red_servidores_web: 10.0.2.40"
echo ""
echo "Resumen de configuración:"
echo "  - NFS exportando a: 10.0.2.0/24"
echo "  - PHP-FPM escuchando en: 0.0.0.0:9000"
echo "  - Firewall: PERMITIR TODO en 10.0.2.0/24"
echo "=========================================="
ls -lh /var/www/html/webapp/ | head -10