# Infraestructura LEMP en Alta Disponibilidad con Vagrant + VirtualBox

Este proyecto despliega en local una aplicación web de Gestión de Usuarios sobre una pila LEMP (Linux, Nginx, MariaDB, PHP-FPM) organizada en 4 capas, utilizando Vagrant (box debian/bookworm64) y VirtualBox.

---

## Arquitectura

- **Capa 1 (pública):**
  - `balanceadorTuNombre`: Servidor Nginx como balanceador de carga HTTP.
  - Expone el puerto 8080 en el host → acceso vía `http://localhost:8080`.

- **Capa 2 (privada):**
  - `serverweb1TuNombre` y `serverweb2TuNombre`: Servidores web Nginx.
  - `serverNFSTuNombre`: Servidor NFS que comparte `/srv/app` y ejecuta PHP-FPM.

- **Capa 3 (privada):**
  - `proxyBBDDTuNombre`: HAProxy balanceando conexiones TCP hacia la base de datos.

- **Capa 4 (privada):**
  - `serverdatosTuNombre`: Servidor MariaDB con la base de datos `gestion_usuarios`.

---

## Requisitos

- VirtualBox
- Vagrant
- Box: `debian/bookworm64`

---

## Uso

1. Clonar o crear el directorio del proyecto.
2. Guardar el `Vagrantfile` en la raíz del proyecto.
3. Crear carpeta `provision/` con los scripts:
   - `lb_nginx.sh`
   - `web_nginx.sh`
   - `nfs_php.sh`
   - `haproxy_db.sh`
   - `mariadb.sh`
4. Arrancar las máquinas sin aprovisionar:
   ```bash
   vagrant up
