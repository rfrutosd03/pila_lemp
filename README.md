# Infraestructura Web de Alta Disponibilidad con Vagrant

## Descripción General

Este proyecto implementa una infraestructura web completa de alta disponibilidad utilizando Vagrant para el aprovisionamiento automático. La arquitectura está diseñada con redundancia en todos los niveles críticos, garantizando disponibilidad continua del servicio incluso ante fallos de componentes individuales.

## Arquitectura del Sistema

La infraestructura se compone de 7 máquinas virtuales organizadas en 4 capas funcionales:

### Diagrama de Red

```
Internet
   ↓
[Balanceador Frontend] 10.50.4.10
   ↓
[Web1: 10.50.3.11] ←→ [Web2: 10.50.3.12]
   ↓                        ↓
[Servidor NFS + PHP-FPM] 10.50.3.10
   ↓
[Proxy BD HAProxy] 10.50.2.10
   ↓
[DB1: 10.50.1.10] ←→ [DB2: 10.50.1.11]
   (Cluster Galera)
```

## Componentes de la Infraestructura

### 1. Capa de Balanceo Frontend (Red 10.50.4.x)

**Máquina:** `balanceadorRicardo` (10.50.4.10)
- **Función:** Punto de entrada único para todas las peticiones HTTP
- **Tecnología:** Nginx como balanceador de carga
- **Algoritmo:** Round-robin para distribución equitativa
- **Características:**
  - Detección automática de servidores caídos (max_fails=3, fail_timeout=30s)
  - Preservación de información del cliente original mediante headers X-Forwarded
  - Endpoint de health check en `/nginx-health`
  - Redirección automática del tráfico a servidores operativos

### 2. Capa de Aplicación Web (Red 10.50.3.x)

#### Servidores Web
- **serverweb1Ricardo** (10.50.3.11)
- **serverweb2Ricardo** (10.50.3.12)

**Función:** Servir contenido web estático y dinámico
**Tecnología:** Nginx como servidor web
**Características:**
- Montaje NFS del directorio `/var/www/html/webapp`
- Configuración idéntica en ambos servidores para garantizar consistencia
- Delegación del procesamiento PHP al servidor centralizado
- Sin estado local (stateless) para facilitar escalado horizontal

#### Servidor NFS y Procesamiento PHP
**Máquina:** `serverNFSRicardo` (10.50.3.10)

**Funciones:**
1. **Almacenamiento centralizado:** 
   - Servidor NFS que comparte `/var/www/html/webapp`
   - Garantiza que todos los servidores web sirven exactamente el mismo contenido
   - Facilita actualizaciones (un solo punto de modificación)

2. **Procesamiento PHP:**
   - PHP-FPM escuchando en puerto 9000
   - Procesamiento centralizado de toda la lógica de aplicación
   - Conexión mediante FastCGI desde los servidores web
   - Optimización de recursos al concentrar el procesamiento PHP

### 3. Capa de Proxy de Base de Datos (Red 10.50.2.x)

**Máquina:** `proxyBDRicardo` (10.50.2.10)

**Función:** Balanceador de carga para el cluster de bases de datos
**Tecnología:** HAProxy en modo TCP
**Características:**
- Distribución de consultas mediante round-robin
- Health checks cada 5 segundos
- Reintentos automáticos ante fallos
- Panel de estadísticas web en puerto 8080
- Transparente para la aplicación (puerto 3306)

**Ventajas:**
- La aplicación no necesita conocer la topología del cluster
- Failover automático sin intervención manual
- Distribución de carga de lectura entre nodos

### 4. Capa de Base de Datos (Red 10.50.1.x)

#### Cluster Galera
- **db1Ricardo** (10.50.1.10) - Nodo primario
- **db2Ricardo** (10.50.1.11) - Nodo secundario

**Tecnología:** MariaDB con Galera Cluster
**Modo de replicación:** Multi-master síncrono

**Características principales:**
1. **Replicación síncrona:**
   - Cada escritura se confirma en todos los nodos antes de retornar
   - Garantía de consistencia total entre nodos
   - Sin pérdida de datos ante fallos

2. **Multi-master:**
   - Escrituras posibles en cualquier nodo
   - Sin nodo único de fallo (SPOF)
   - Ambos nodos son activos simultáneamente

3. **Sincronización:**
   - Método: rsync para transferencia de estado
   - Formato de binlog: ROW para replicación precisa
   - InnoDB con autoinc_lock_mode=2 para mejor concurrencia

## Flujo de una Petición HTTP

1. **Cliente** → Envía petición HTTP a `10.50.4.10:80`
2. **Balanceador Nginx** → Selecciona un servidor web (round-robin)
3. **Servidor Web** (10.50.3.11 o 10.50.3.12) → Recibe la petición
4. **Si es contenido estático:** Lee desde NFS y retorna
5. **Si es PHP:**
   - Nginx envía petición FastCGI a `10.50.3.10:9000`
   - **PHP-FPM** procesa el código PHP
   - Si necesita BD: Conecta a `10.50.2.10:3306`
6. **HAProxy** → Selecciona un nodo de BD y reenvía
7. **Cluster Galera** → Procesa la consulta
8. **Respuesta inversa** por el mismo camino hasta el cliente

## Esquema de Direccionamiento IP

| Máquina | Red Principal | Redes Secundarias | Propósito |
|---------|---------------|-------------------|-----------|
| balanceadorRicardo | 10.50.4.10 | 10.50.3.20 | Frontend público + Acceso a servidores web |
| serverweb1Ricardo | 10.50.3.11 | - | Servidor web + Cliente NFS |
| serverweb2Ricardo | 10.50.3.12 | - | Servidor web + Cliente NFS |
| serverNFSRicardo | 10.50.3.10 | 10.50.2.11 | NFS + PHP-FPM + Acceso a BD |
| proxyBDRicardo | 10.50.2.10 | 10.50.1.20 | Proxy BD + Acceso a cluster |
| db1Ricardo | 10.50.1.10 | - | Nodo 1 Galera |
| db2Ricardo | 10.50.1.11 | - | Nodo 2 Galera |

## Configuración de Base de Datos

### Base de datos y usuarios
- **Base de datos:** `lamp_db` (utf8mb4)
- **Usuario aplicación:** `ricardo` / `1234` (permisos completos en lamp_db)
- **Usuario HAProxy:** `haproxy` / sin password (solo USAGE para health checks)
- **Usuario admin:** `root` / `root` (acceso remoto completo)

## Instalación y Despliegue

### Requisitos previos
- Vagrant >= 2.0
- VirtualBox >= 6.0
- 8 GB RAM disponible
- 20 GB espacio en disco

### Estructura de directorios
```
proyecto/
├── Vagrantfile
└── provision/
    ├── bd.sh
    ├── bd2.sh
    ├── proxybd.sh
    ├── nfs.sh
    ├── web.sh
    ├── web2.sh
    └── bl.sh
```

### Comandos de despliegue

**Levantar toda la infraestructura:**
```bash
vagrant up
```

**Levantar máquinas individuales:**
```bash
vagrant up db1Ricardo
vagrant up db2Ricardo
vagrant up proxyBDRicardo
vagrant up serverNFSRicardo
vagrant up serverweb1Ricardo
vagrant up serverweb2Ricardo
vagrant up balanceadorRicardo
```

**Orden recomendado de aprovisionamiento:**
1. Bases de datos (db1Ricardo → db2Ricardo)
2. Proxy de BD (proxyBDRicardo)
3. Servidor NFS (serverNFSRicardo)
4. Servidores web (serverweb1Ricardo, serverweb2Ricardo)
5. Balanceador frontend (balanceadorRicardo)

### Verificación del despliegue

**Verificar conectividad de todas las máquinas:**
```bash
ping -c 1 10.50.1.10; ping -c 1 10.50.1.11; ping -c 1 10.50.2.10; ping -c 1 10.50.3.10; ping -c 1 10.50.3.11; ping -c 1 10.50.3.12; ping -c 1 10.50.4.10
```

**Verificar cluster Galera:**
```bash
vagrant ssh db1Ricardo -c "mysql -e \"SHOW STATUS LIKE 'wsrep_cluster_size';\""
```
Debe mostrar: `wsrep_cluster_size = 2`

**Verificar montaje NFS:**
```bash
vagrant ssh serverweb1Ricardo -c "df -h | grep webapp"
vagrant ssh serverweb2Ricardo -c "df -h | grep webapp"
```

**Verificar PHP-FPM:**
```bash
vagrant ssh serverNFSRicardo -c "netstat -tlnp | grep 9000"
```

**Verificar HAProxy:**
```bash
curl http://10.50.2.10:8080/stats
# Usuario: admin / Contraseña: admin
```

## Acceso a la Aplicación

### Desde el host (tu máquina):
- **Aplicación web:** http://localhost:8080
- **Panel HAProxy:** http://10.50.2.10:8080/stats (admin/admin)
- **Info PHP:** http://localhost:8080/info.php

### Desde dentro de las VMs:
- **Balanceador:** http://10.50.4.10
- **Web1 directa:** http://10.50.3.11
- **Web2 directa:** http://10.50.3.12

## Pruebas de Alta Disponibilidad

### Test 1: Caída de un servidor web
```bash
vagrant halt serverweb1Ricardo
curl http://localhost:8080
# La aplicación sigue funcionando a través de serverweb2Ricardo
```

### Test 2: Caída de un nodo de BD
```bash
vagrant halt db2Ricardo
# Verificar que el cluster sigue operativo
vagrant ssh db1Ricardo -c "mysql -e \"SHOW STATUS LIKE 'wsrep_cluster_size';\""
# Debe mostrar: wsrep_cluster_size = 1
# La aplicación sigue funcionando normalmente
```

### Test 3: Replicación del cluster
```bash
# Insertar datos en db1Ricardo
vagrant ssh db1Ricardo -c "mysql lamp_db -u ricardo -p1234 -e \"INSERT INTO tabla VALUES (...);\""

# Verificar en db2Ricardo
vagrant ssh db2Ricardo -c "mysql lamp_db -u ricardo -p1234 -e \"SELECT * FROM tabla;\""
# Los datos deben estar presentes inmediatamente
```

## Mantenimiento y Operaciones

### Comandos útiles de Vagrant

**Ver estado de todas las máquinas:**
```bash
vagrant status
```

**Conectar por SSH:**
```bash
vagrant ssh <nombre_maquina>
```

**Reiniciar una máquina:**
```bash
vagrant reload <nombre_maquina>
```

**Reprovisionar (ejecutar scripts nuevamente):**
```bash
vagrant provision <nombre_maquina>
```

**Destruir y recrear:**
```bash
vagrant destroy <nombre_maquina>
vagrant up <nombre_maquina>
```

**Detener todas las máquinas:**
```bash
vagrant halt
```

**Eliminar completamente la infraestructura:**
```bash
vagrant destroy -f
```

### Logs importantes

**Nginx (servidores web y balanceador):**
- `/var/log/nginx/access.log`
- `/var/log/nginx/error.log`

**HAProxy:**
- `/var/log/haproxy.log`

**MariaDB:**
- `/var/log/mysql/error.log`

**PHP-FPM:**
- `/var/log/php8.2-fpm.log` (versión puede variar)

### Monitoreo

**Ver logs en tiempo real:**
```bash
vagrant ssh balanceadorRicardo -c "tail -f /var/log/nginx/access.log"
```

**Estado del cluster Galera:**
```bash
vagrant ssh db1Ricardo -c "mysql -e \"SHOW STATUS LIKE 'wsrep_%';\""
```

**Estadísticas HAProxy:**
- Navegador: http://10.50.2.10:8080/stats
- CLI: `echo "show stat" | socat /run/haproxy/admin.sock stdio`

## Características de Alta Disponibilidad

### Puntos de redundancia:
- ✅ **Capa web:** 2 servidores Nginx (failover automático por balanceador)
- ✅ **Capa BD:** 2 nodos Galera (multi-master con replicación síncrona)
- ✅ **Balanceo:** Nginx frontend y HAProxy backend
- ✅ **Almacenamiento:** NFS centralizado (único punto, considerar DRBD para HA completo)
- ✅ **Procesamiento PHP:** Centralizado (único punto, considerar replicación para HA completo)

### Puntos únicos de fallo actuales:
- ⚠️ Balanceador frontend (considerar Keepalived + VRRP para HA)
- ⚠️ Servidor NFS (considerar DRBD o GlusterFS para HA)
- ⚠️ Proxy HAProxy (considerar segundo HAProxy con IP virtual)

## Escalabilidad

### Escalado horizontal fácil:
1. **Agregar servidores web:**
   - Clonar configuración de web.sh con nueva IP
   - Agregar al upstream del balanceador
   - Montar mismo NFS

2. **Agregar nodos Galera:**
   - Configurar nuevo nodo con IPs del cluster
   - Iniciar con `systemctl start mariadb`
   - Agregar al backend de HAProxy

### Escalado vertical:
- Modificar Vagrantfile para asignar más RAM/CPU:
```ruby
config.vm.provider "virtualbox" do |vb|
  vb.memory = "2048"
  vb.cpus = 2
end
```

## Solución de Problemas

### Problema: Cluster Galera no sincroniza
```bash
# Verificar estado en ambos nodos
mysql -e "SHOW STATUS LIKE 'wsrep_cluster_status';"
# Debe mostrar: Primary

# Si un nodo está en Non-Primary:
systemctl stop mariadb
rm -rf /var/lib/mysql/grastate.dat
systemctl start mariadb
```

### Problema: NFS no monta
```bash
# Verificar que el servidor NFS está exportando
showmount -e 10.50.3.10

# Forzar montaje
umount /var/www/html/webapp
mount -t nfs 10.50.3.10:/var/www/html/webapp /var/www/html/webapp
```

### Problema: PHP no procesa
```bash
# Verificar PHP-FPM
systemctl status php*-fpm
netstat -tlnp | grep 9000

# Verificar conectividad desde servidores web
nc -zv 10.50.3.10 9000
```

## Seguridad

### Recomendaciones para producción:
1. Cambiar todas las contraseñas por defecto
2. Configurar firewall (ufw/iptables) en cada máquina
3. Implementar SSL/TLS en el balanceador frontend
4. Restringir acceso SSH por clave pública
5. Configurar fail2ban para protección contra fuerza bruta
6. Actualizar regularmente todos los paquetes
7. Implementar backups automáticos de la BD
8. Monitorear logs con herramientas como ELK Stack

## Tecnologías Utilizadas

- **Vagrant:** Automatización de infraestructura
- **VirtualBox:** Virtualización
- **Debian Bookworm:** Sistema operativo base
- **Nginx:** Servidor web y balanceador de carga
- **PHP-FPM:** Procesamiento de PHP
- **MariaDB + Galera:** Base de datos con clustering
- **HAProxy:** Balanceador de carga TCP para BD
- **NFS:** Sistema de archivos en red
- **rsync:** Sincronización de estado Galera

## Autor

Ricardo - Infraestructura de Alta Disponibilidad

## Licencia

Este proyecto es de código abierto y está disponible bajo licencia MIT.
