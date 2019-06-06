##########################################
########### Storage Account  #############
##########################################

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  version = "~> 2.1"
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.rg1.name}"
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = "${azurerm_resource_group.rg1.name}"
  location                 = "${var.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = "${var.envtags}"
}

##########################################
########### Security Groups  #############
##########################################

# Create NSG for Jumphost
resource "azurerm_network_security_group" "mgmt-nsg" {
  name                = "my_mgmt-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg1.name}"

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create NSG for Web hosts
resource "azurerm_network_security_group" "webnsg" {
  name                = "web_nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg1.name}"
  tags                = "${var.envtags}"
}

##########################################
########## Jumphost in East  #############
##########################################

# Public IP for Jumphost
resource "azurerm_public_ip" "pub1" {
  name                = "${var.vm_mgmt}-pub"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg1.name}"
  allocation_method   = "Dynamic"
}

# Create interface for virtual machine
resource "azurerm_network_interface" "ni3" {
  name                = "${var.vm_mgmt}-eth0"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg1.name}"
  network_security_group_id = "${azurerm_network_security_group.mgmt-nsg.id}"

  ip_configuration {
    name                          = "config1"
    subnet_id                     = "${azurerm_subnet.sub2.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id		  = "${azurerm_public_ip.pub1.id}"
  }
}

# Create virtual machine
resource "azurerm_virtual_machine" "my_mgmt" {
  name                  = "${var.vm_mgmt}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.rg1.name}"
  network_interface_ids = ["${azurerm_network_interface.ni3.id}"]
  vm_size               = "Standard_DS1_v2"
  tags                  = "${var.envtags}"
	
  storage_os_disk {
    name              = "mgmtOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "myMgmt"
    admin_username = "astrand"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/astrand/.ssh/authorized_keys"
      key_data = "${var.ssh_key}"
    }
  }

  boot_diagnostics {
    enabled = "true"
    storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
  }
}

##########################################
############ Host1 in West  ##############
##########################################

# Create interface for virtual machine
resource "azurerm_network_interface" "ni1" {
  name                = "${var.vm_name1}-eth0"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg1.name}"
  network_security_group_id = "${azurerm_network_security_group.webnsg.id}"

  ip_configuration {
    name                          = "config1"
    subnet_id                     = "${azurerm_subnet.sub1.id}"
    private_ip_address_allocation = "dynamic"
  }
}

# Create backend pool association
resource "azurerm_network_interface_backend_address_pool_association" "test1" {
  network_interface_id    = "${azurerm_network_interface.ni1.id}"
  ip_configuration_name   = "config1"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.bpepool3.id}"
}

# Create virtual machine
resource "azurerm_virtual_machine" "my_web1" {
  name                  = "${var.vm_name1}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.rg1.name}"
  network_interface_ids = ["${azurerm_network_interface.ni1.id}"]
  vm_size               = "Standard_D2S_v3"
  tags                  = "${var.servertags}"
	
  storage_os_disk {
    name              = "webOsDisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "myWeb01"
    admin_username = "astrand"
    custom_data = "${var.ubuntu_user_data}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/astrand/.ssh/authorized_keys"
      key_data = "${var.ssh_key}"
    }
  }

  boot_diagnostics {
    enabled = "true"
    storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
  }
}

##########################################
############ Host2 in West  ##############
##########################################

# Create interface for virtual machine
resource "azurerm_network_interface" "ni2" {
  name                = "${var.vm_name2}-eth0"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg1.name}"
  network_security_group_id = "${azurerm_network_security_group.webnsg.id}"

  ip_configuration {
    name                          = "config1"
    subnet_id                     = "${azurerm_subnet.sub1.id}"
    private_ip_address_allocation = "dynamic"
  }
}

# Create backend pool association
resource "azurerm_network_interface_backend_address_pool_association" "test2" {
  network_interface_id    = "${azurerm_network_interface.ni2.id}"
  ip_configuration_name   = "config1"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.bpepool3.id}"
}

# Create virtual machine
resource "azurerm_virtual_machine" "my_web2" {
  name                  = "${var.vm_name2}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.rg1.name}"
  network_interface_ids = ["${azurerm_network_interface.ni2.id}"]
  vm_size               = "Standard_D2S_v3"
  tags                  = "${var.servertags}"
	
  storage_os_disk {
    name              = "webOsDisk2"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "myWeb02"
    admin_username = "astrand"
    custom_data = "${var.ubuntu_user_data}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/astrand/.ssh/authorized_keys"
      key_data = "${var.ssh_key}"
    }
  }

  boot_diagnostics {
    enabled = "true"
    storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
  }
}