# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"
  

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "512"
    vb.cpus = 1
  end

  config.vm.define "balanceadorricardo" do |balancer|
    balancer.vm.hostname = "balanceadorricardo"
    # Interfaz hacia Internet/Cliente (DMZ)
    balancer.vm.network "private_network", ip: "192.168.10.10"
    # Interfaz hacia Backend
    balancer.vm.network "private_network", ip: "192.168.2.10"
    balancer.vm.network "forwarded_port", guest: 80, host: 8080
    balancer.vm.provision "shell", path: "provision/balanceador.sh"
    balancer.vm.provider "virtualbox" do |vb|
      vb.name = "balanceadorricardo"
    end
  end

  config.vm.define "serverNFSricardo" do |nfs|
    nfs.vm.hostname = "serverNFSricardo"
    # Interfaz hacia Servidores Web
    nfs.vm.network "private_network", ip: "192.168.3.23"
    # Interfaz hacia Proxy BD
    nfs.vm.network "private_network", ip: "192.168.4.23"
    nfs.vm.provision "shell", path: "provision/servernfs.sh"
    nfs.vm.provider "virtualbox" do |vb|
      vb.name = "serverNFSricardo"
      vb.memory = "768"
    end
  end
  
  config.vm.define "serverweb1ricardo" do |web1|
    web1.vm.hostname = "serverweb1ricardo"
    # Interfaz hacia Balanceador
    web1.vm.network "private_network", ip: "192.168.2.21"
    # Interfaz hacia NFS
    web1.vm.network "private_network", ip: "192.168.3.21"
    web1.vm.provision "shell", path: "provision/serverweb.sh"
    web1.vm.provider "virtualbox" do |vb|
      vb.name = "serverweb1ricardo"
    end
  end

  config.vm.define "serverweb2ricardo" do |web2|
    web2.vm.hostname = "serverweb2ricardo"
    # Interfaz hacia Balanceador
    web2.vm.network "private_network", ip: "192.168.2.22"
    # Interfaz hacia NFS
    web2.vm.network "private_network", ip: "192.168.3.22"
    web2.vm.provision "shell", path: "provision/serverweb.sh"
    web2.vm.provider "virtualbox" do |vb|
      vb.name = "serverweb2ricardo"
    end
  end


  config.vm.define "proxyBBDDricardo" do |proxy|
    proxy.vm.hostname = "proxyBBDDricardo"
    # Interfaz hacia NFS/Aplicacion
    proxy.vm.network "private_network", ip: "192.168.4.30"
    # Interfaz hacia Base de Datos
    proxy.vm.network "private_network", ip: "192.168.5.30"
    proxy.vm.provision "shell", path: "provision/proxybbdd.sh"
    proxy.vm.provider "virtualbox" do |vb|
      vb.name = "proxyBBDDricardo"
    end
  end

  config.vm.define "serverdatosricardo" do |db|
    db.vm.hostname = "serverdatosricardo"
    db.vm.network "private_network", ip: "192.168.5.40"
    db.vm.provision "shell", path: "provision/serverbbdd.sh"
    db.vm.provider "virtualbox" do |vb|
      vb.name = "serverdatosricardo"
      vb.memory = "768"
    end
  end
end