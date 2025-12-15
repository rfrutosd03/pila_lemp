Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"

  # Configuración común para todas las VMs
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "512"
    vb.cpus = 1
    # Habilitar modo promiscuo para mejor conectividad en redes internas
    vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
    vb.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
  end

  # Script común para configurar red en todas las VMs
  $configure_network = <<-SCRIPT
    echo "Configurando red base..."
    
    # Asegurar que todas las interfaces eth estén up
    for iface in eth1 eth2 eth3; do
      if ip link show $iface >/dev/null 2>&1; then
        ip link set $iface up 2>/dev/null || true
      fi
    done
    
    # Mostrar configuración de red
    echo "Interfaces de red configuradas:"
    ip addr show | grep -E "(eth|inet )"
    
    # Deshabilitar offloading que puede causar problemas
    for iface in eth0 eth1 eth2 eth3; do
      if ip link show $iface >/dev/null 2>&1; then
        ethtool -K $iface tx off rx off 2>/dev/null || true
      fi
    done
  SCRIPT

  # Orden de inicio: DB1 -> DB2 -> HAProxy -> NFS -> Web1 -> Web2 -> Balanceador
  
  # 1. DB1 - Base de datos primaria
  config.vm.define "db1", autostart: true do |db1|
    db1.vm.hostname = "db1"
    db1.vm.network "private_network", 
      ip: "10.0.4.20", 
      virtualbox__intnet: "red_base_datos",
      auto_config: true
    
    db1.vm.provider "virtualbox" do |vb|
      vb.name = "lamp-db1"
      vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
    end
    
    db1.vm.provision "shell", inline: $configure_network
    db1.vm.provision "shell", path: "scripts/db1.sh"
  end

  # 2. DB2 - Base de datos secundaria
  config.vm.define "db2", autostart: true do |db2|
    db2.vm.hostname = "db2"
    db2.vm.network "private_network", 
      ip: "10.0.4.30", 
      virtualbox__intnet: "red_base_datos",
      auto_config: true
    
    db2.vm.provider "virtualbox" do |vb|
      vb.name = "lamp-db2"
      vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
    end
    
    db2.vm.provision "shell", inline: $configure_network
    db2.vm.provision "shell", path: "scripts/db2.sh"
  end

  # 3. HAPROXY - Balanceador de base de datos
  config.vm.define "haproxy", autostart: true do |haproxy|
    haproxy.vm.hostname = "haproxy"
    haproxy.vm.network "private_network", 
      ip: "10.0.3.20", 
      virtualbox__intnet: "red_aplicaciones",
      auto_config: true
    haproxy.vm.network "private_network", 
      ip: "10.0.4.10", 
      virtualbox__intnet: "red_base_datos",
      auto_config: true
    
    haproxy.vm.provider "virtualbox" do |vb|
      vb.name = "lamp-haproxy"
      vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
      vb.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
    end
    
    haproxy.vm.provision "shell", inline: $configure_network
    haproxy.vm.provision "shell", path: "scripts/haproxy.sh"
  end

  # 4. NFS - Servidor de archivos y PHP-FPM
  config.vm.define "nfs", autostart: true do |nfs|
    nfs.vm.hostname = "nfs"
    # CRÍTICO: Primera interfaz en red_servidores_web
    nfs.vm.network "private_network", 
      ip: "10.0.2.40", 
      virtualbox__intnet: "red_servidores_web",
      auto_config: true,
      nic_type: "virtio"
    nfs.vm.network "private_network", 
      ip: "10.0.3.10", 
      virtualbox__intnet: "red_aplicaciones",
      auto_config: true
    
    nfs.vm.provider "virtualbox" do |vb|
      vb.name = "lamp-nfs"
      vb.memory = "768"
      # Modo promiscuo crítico para NFS
      vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
      vb.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
    end
    
    nfs.vm.provision "shell", inline: $configure_network
    nfs.vm.provision "shell", path: "scripts/nfs.sh"
  end

  # 5. WEB1 - Servidor web 1
  config.vm.define "web1", autostart: true do |web1|
    web1.vm.hostname = "web1"
    web1.vm.network "private_network", 
      ip: "10.0.2.20", 
      virtualbox__intnet: "red_servidores_web",
      auto_config: true,
      nic_type: "virtio"
    
    web1.vm.provider "virtualbox" do |vb|
      vb.name = "lamp-web1"
      vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
    end
    
    web1.vm.provision "shell", inline: $configure_network
    web1.vm.provision "shell", path: "scripts/web1.sh"
  end

  # 6. WEB2 - Servidor web 2
  config.vm.define "web2", autostart: true do |web2|
    web2.vm.hostname = "web2"
    web2.vm.network "private_network", 
      ip: "10.0.2.30", 
      virtualbox__intnet: "red_servidores_web",
      auto_config: true,
      nic_type: "virtio"
    
    web2.vm.provider "virtualbox" do |vb|
      vb.name = "lamp-web2"
      vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
    end
    
    web2.vm.provision "shell", inline: $configure_network
    web2.vm.provision "shell", path: "scripts/web2.sh"
  end

  # 7. BALANCEADOR - Punto de entrada HTTP
  config.vm.define "balanceador", autostart: true do |balanceador|
    balanceador.vm.hostname = "balanceador"
    balanceador.vm.network "private_network", 
      ip: "10.0.1.10", 
      virtualbox__intnet: "red_publica",
      auto_config: true
    balanceador.vm.network "private_network", 
      ip: "10.0.2.10", 
      virtualbox__intnet: "red_servidores_web",
      auto_config: true
    balanceador.vm.network "forwarded_port", guest: 80, host: 8080
    
    balanceador.vm.provider "virtualbox" do |vb|
      vb.name = "lamp-balanceador"
      vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
      vb.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
    end
    
    balanceador.vm.provision "shell", inline: $configure_network
    balanceador.vm.provision "shell", path: "scripts/balanceador.sh"
  end
end