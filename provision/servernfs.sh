#!/bin/bash

echo "Iniciando aprovisionamiento del servidor NFS y PHP-FPM..."

echo "Actualizando sistema..."
apt-get update
apt-get upgrade -y

echo "Instalando NFS y PHP..."
apt-get install -y nfs-kernel-server php-fpm php-mysql php-cli php-common php-mbstring php-xml php-zip php-curl

echo "Creando directorio compartido NFS..."
mkdir -p /var/nfs/shared
chown -R www-data:www-data /var/nfs/shared
chmod -R 755 /var/nfs/shared

echo "Configurando exports de NFS..."
cat > /etc/exports <<'EOF'
/var/nfs/shared 192.168.3.21(rw,sync,no_subtree_check,no_root_squash)
/var/nfs/shared 192.168.3.22(rw,sync,no_subtree_check,no_root_squash)
EOF

echo "Aplicando configuracion NFS..."
exportfs -a
systemctl restart nfs-kernel-server
systemctl enable nfs-kernel-server

echo "Configurando PHP-FPM..."
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_FPM_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"

cp $PHP_FPM_CONF ${PHP_FPM_CONF}.backup

sed -i 's/listen = .*/listen = 0.0.0.0:9000/' $PHP_FPM_CONF
sed -i 's/;listen.allowed_clients/listen.allowed_clients/' $PHP_FPM_CONF
sed -i 's/listen.allowed_clients = .*/listen.allowed_clients = 192.168.3.21,192.168.3.22/' $PHP_FPM_CONF

echo "Reiniciando PHP-FPM..."
systemctl restart php${PHP_VERSION}-fpm
systemctl enable php${PHP_VERSION}-fpm

echo "Creando archivo de configuracion de base de datos..."
cat > /var/nfs/shared/config.php <<'PHPEOF'
<?php

define('DB_HOST', '192.168.4.30');
define('DB_NAME', 'lamp_db');
define('DB_USER', 'ricardo');
define('DB_PASSWORD', 'ricardo123');

$mysqli = mysqli_connect(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);

?>
PHPEOF

echo "Creando pagina principal (index.php)..."
cat > /var/nfs/shared/index.php <<'PHPEOF'
<?php
include_once("config.php");

$result = mysqli_query($mysqli, "SELECT * FROM users ORDER BY id DESC");
?>

<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">
	<title>Homepage</title>
	<link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.1/css/bootstrap.min.css"  crossorigin="anonymous">	
</head>

<body>
<div class = "container">
	<div class="jumbotron">
      <h1 class="display-4">Simple LAMP web app</h1>
      <p class="lead">Demo app - Server: <?php echo gethostname(); ?></p>
    </div>	
	<a href="add.html" class="btn btn-primary">Add New Data</a><br/><br/>
	<table width='80%' border=0 class="table">

	<tr bgcolor='#CCCCCC'>
		<td>Name</td>
		<td>Age</td>
		<td>Email</td>
		<td>Update</td>
	</tr>

	<?php
	while($res = mysqli_fetch_array($result)) {
		echo "<tr>\n";
		echo "<td>".$res['name']."</td>\n";
		echo "<td>".$res['age']."</td>\n";
		echo "<td>".$res['email']."</td>\n";
		echo "<td><a href=\"edit.php?id=$res[id]\">Edit</a> | <a href=\"delete.php?id=$res[id]\" onClick=\"return confirm('Are you sure you want to delete?')\">Delete</a></td>\n";
		echo "</tr>\n";
	}

	mysqli_close($mysqli);
	?>
	</table>
</div>
</body>
</html>
PHPEOF

echo "Creando formulario de agregar usuario (add.html)..."
cat > /var/nfs/shared/add.html <<'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">	
	<title>Add Data</title>
	<link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.1/css/bootstrap.min.css"  crossorigin="anonymous">
</head>

<body>
<div class = "container">
		<div class="jumbotron">
			<h1 class="display-4">Simple LAMP web app</h1>
			<p class="lead">Demo app</p>
		</div>
			
	<a href="index.php" class="btn btn-primary">Home</a>
	<br/><br/>

	<form action="add.php" method="post" name="form1">

		<div class="form-group">
			<label for="name">Name</label>
			<input type="text" class="form-control" name="name">
		</div>

		<div class="form-group">
			<label for="age">Age</label>
			<input type="text" class="form-control" name="age">
		</div>

		<div class="form-group">
			<label for="email">Email</label>
			<input type="text" class="form-control" name="email">
		</div>

		<div class="form-group">
			<input type="submit" name="Submit" value="Add" class="form-control" >
		</div>
	</form>
</div>
</body>
</html>
HTMLEOF

echo "Creando procesador de agregar usuario (add.php)..."
cat > /var/nfs/shared/add.php <<'PHPEOF'
<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">
	<title>Add Data</title>
	<link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.1/css/bootstrap.min.css"  crossorigin="anonymous">
</head>

<body>
<div class = "container">
	<div class="jumbotron">
		<h1 class="display-4">Simple LAMP web app</h1>
		<p class="lead">Demo app</p>
	</div>


<?php
include_once("config.php");

if(isset($_POST['Submit'])) {
	$name = mysqli_real_escape_string($mysqli, $_POST['name']);
	$age = mysqli_real_escape_string($mysqli, $_POST['age']);
	$email = mysqli_real_escape_string($mysqli, $_POST['email']);

	if(empty($name) || empty($age) || empty($email)) {
		if(empty($name)) {
			echo "<div class='alert alert-danger' role='alert'>Name field is empty</div>";
		}

		if(empty($age)) {
			echo "<div class='alert alert-danger' role='alert'>Age field is empty</div>";
		}

		if(empty($email)) {
			echo "<div class='alert alert-danger' role='alert'>Email field is empty</div>";
		}

		echo "<a href='javascript:self.history.back();' class='btn btn-primary'>Go Back</a>";
	} else {
		$stmt = mysqli_prepare($mysqli, "INSERT INTO users(name,age,email) VALUES(?,?,?)");
		mysqli_stmt_bind_param($stmt, "sis", $name, $age, $email);
		mysqli_stmt_execute($stmt);
		mysqli_stmt_free_result($stmt);
		mysqli_stmt_close($stmt);

		echo "<div class='alert alert-success' role='alert'>Data added successfully</div>";
		echo "<a href='index.php' class='btn btn-primary'>View Result</a>";
	}
}

mysqli_close($mysqli);

?>
</div>
</body>
</html>
PHPEOF

echo "Creando editor de usuarios (edit.php)..."
cat > /var/nfs/shared/edit.php <<'PHPEOF'
<?php
include_once("config.php");

if(isset($_POST['update'])) {
	$id = mysqli_real_escape_string($mysqli, $_POST['id']);
	$name = mysqli_real_escape_string($mysqli, $_POST['name']);
	$age = mysqli_real_escape_string($mysqli, $_POST['age']);
	$email = mysqli_real_escape_string($mysqli, $_POST['email']);

	if(empty($name) || empty($age) || empty($email)) {
		if(empty($name)) {
			echo "<font color='red'>Name field is empty.</font><br/>";
		}

		if(empty($age)) {
			echo "<font color='red'>Age field is empty.</font><br/>";
		}

		if(empty($email)) {
			echo "<font color='red'>Email field is empty.</font><br/>";
		}
	} else {
		$stmt = mysqli_prepare($mysqli, "UPDATE users SET name=?,age=?,email=? WHERE id=?");
		mysqli_stmt_bind_param($stmt, "sisi", $name, $age, $email, $id);
		mysqli_stmt_execute($stmt);
		mysqli_stmt_free_result($stmt);
		mysqli_stmt_close($stmt);

		header("Location: index.php");
	}
}
?>

<?php
$id = $_GET['id'];

$stmt = mysqli_prepare($mysqli, "SELECT name, age, email FROM users WHERE id=?");
mysqli_stmt_bind_param($stmt, "i", $id);
mysqli_stmt_execute($stmt);
mysqli_stmt_bind_result($stmt, $name, $age, $email);
mysqli_stmt_fetch($stmt);
mysqli_stmt_free_result($stmt);
mysqli_stmt_close($stmt);
mysqli_close($mysqli);
?>

<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">
	<title>Edit Data</title>
	<link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.1/css/bootstrap.min.css"  crossorigin="anonymous">
</head>

<body>
<div class = "container">
	<div class="jumbotron">
		<h1 class="display-4">Simple LAMP web app</h1>
		<p class="lead">Demo app</p>
	</div>

	<a href="index.php" class="btn btn-primary">Home</a>
	<br/><br/>

	<form name="form1" method="post" action="edit.php">

		<div class="form-group">
			<label for="name">Name</label>
			<input type="text" class="form-control" name="name" value="<?php echo $name;?>">
		</div>

		<div class="form-group">
			<label for="name">Age</label>
			<input type="text" class="form-control" name="age" value="<?php echo $age;?>">
		</div>

		<div class="form-group">
			<label for="name">Email</label>
			<input type="text" class="form-control" name="email" value="<?php echo $email;?>">
		</div>

		<div class="form-group">
			<input type="hidden" name="id" value=<?php echo $_GET['id'];?>>
			<input type="submit" name="update" value="Update" class="form-control" >
		</div>

	</form>
</div>
</body>
</html>
PHPEOF

echo "Creando eliminador de usuarios (delete.php)..."
cat > /var/nfs/shared/delete.php <<'PHPEOF'
<?php
include("config.php");

$id = $_GET['id'];

$stmt = mysqli_prepare($mysqli, "DELETE FROM users WHERE id=?");
mysqli_stmt_bind_param($stmt, "i", $id);
mysqli_stmt_execute($stmt);
mysqli_stmt_close($stmt);
mysqli_close($mysqli);

header("Location:index.php");
?>
PHPEOF

echo "Estableciendo permisos correctos..."
chown -R www-data:www-data /var/nfs/shared
chmod -R 755 /var/nfs/shared
find /var/nfs/shared -type f -exec chmod 644 {} \;

echo "Verificando configuracion NFS..."
exportfs -v

echo ""
echo "Verificando PHP-FPM..."
netstat -tulpn | grep 9000

echo ""
echo "Archivos de aplicacion creados:"
ls -lh /var/nfs/shared/

echo ""
echo "Servidor NFS y PHP-FPM configurado correctamente"