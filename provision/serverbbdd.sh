#!/bin/bash

echo "Iniciando aprovisionamiento del servidor de base de datos..."

echo "Actualizando sistema..."
apt-get update
apt-get upgrade -y

echo "Instalando MariaDB..."
DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server

echo "Configurando MariaDB para escuchar en todas las interfaces..."
cat > /etc/mysql/mariadb.conf.d/60-server.cnf <<'EOF'
[server]
[mysqld]
bind-address = 0.0.0.0
max_connections = 200

[embedded]
[mariadb]
[mariadb-10.5]
EOF

echo "Reiniciando MariaDB..."
systemctl restart mariadb
systemctl enable mariadb

echo "Esperando a que MariaDB este listo..."
sleep 5

echo "Creando base de datos y usuarios..."
mysql -u root <<'MYSQLEOF'
CREATE DATABASE IF NOT EXISTS lamp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'ricardo'@'%' IDENTIFIED BY 'ricardo123';
GRANT ALL PRIVILEGES ON lamp_db.* TO 'ricardo'@'%';

CREATE USER IF NOT EXISTS 'haproxy'@'%';
GRANT USAGE ON *.* TO 'haproxy'@'%';

USE lamp_db;

CREATE TABLE IF NOT EXISTS users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    age INT UNSIGNED NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO users (name, age, email) VALUES
('Ricardo Frutos', 28, 'ricardo.frutos@gmail.com')
ON DUPLICATE KEY UPDATE name=VALUES(name);

FLUSH PRIVILEGES;
MYSQLEOF

echo "Verificando usuarios creados..."
mysql -u root -e "SELECT User, Host FROM mysql.user WHERE User IN ('ricardo', 'haproxy');"

echo "Verificando tablas creadas..."
mysql -u root -e "USE lamp_db; SHOW TABLES;"

echo "Mostrando datos de ejemplo..."
mysql -u root -e "USE lamp_db; SELECT * FROM users;"

echo "Servidor de base de datos configurado correctamente"