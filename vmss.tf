resource "random_string" "fqdn" {
  length  = 6
  special = false
  upper   = false
  number  = false
}

##########################################
############ Security Group  #############
##########################################

# NSG for VMSS
resource "azurerm_network_security_group" "vmssnsg" {
  name                = "CPVMSS_nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg2.name
  tags                = var.envtags

  security_rule {
    name                       = "AllowAllInBound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

##########################################
############## Public IP  ################
##########################################

# Public IP for External LB
resource "azurerm_public_ip" "vmss-extlb" {
  name                = "CPVMSS-app-1"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg2.name
  allocation_method   = "Static"
  domain_name_label   = random_string.fqdn.result
  sku                 = "Standard"
  tags                = var.envtags
}

##########################################
############ Load Balancers  #############
##########################################

# External VMSS Load Balancer
resource "azurerm_lb" "vmssext" {
  name                = "frontend-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg2.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "CPVMSS-app-1"
    public_ip_address_id = azurerm_public_ip.vmss-extlb.id
  }

  tags = var.envtags
}

# Internal VMSS Load Balancer
resource "azurerm_lb" "vmssint" {
  name                = "backend-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg2.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "CPVMSS-int"
    subnet_id                     = azurerm_subnet.sub4.id
    private_ip_address            = cidrhost(azurerm_subnet.sub4.address_prefix, 4)
    private_ip_address_allocation = "Static"
  }

  tags = var.envtags
}

##########################################
########### LB Backend pool  #############
##########################################

# Backend pool for External LB
resource "azurerm_lb_backend_address_pool" "bpepool1" {
  resource_group_name = azurerm_resource_group.rg2.name
  loadbalancer_id     = azurerm_lb.vmssext.id
  name                = "FrontEndAddressPool"
}

# Backend pool for Internal LB
resource "azurerm_lb_backend_address_pool" "bpepool2" {
  resource_group_name = azurerm_resource_group.rg2.name
  loadbalancer_id     = azurerm_lb.vmssint.id
  name                = "BackEndAddressPool"
}

##########################################
############## LB Probes  ################
##########################################

# LB probe for External LB
resource "azurerm_lb_probe" "vmssprobe1" {
  resource_group_name = azurerm_resource_group.rg2.name
  loadbalancer_id     = azurerm_lb.vmssext.id
  name                = "cp-probe"
  protocol            = "Tcp"
  port                = 8117
  interval_in_seconds = 5
  number_of_probes    = 2
}

# LB probe for Internal LB
resource "azurerm_lb_probe" "vmssprobe2" {
  resource_group_name = azurerm_resource_group.rg2.name
  loadbalancer_id     = azurerm_lb.vmssint.id
  name                = "cp-probe"
  protocol            = "Tcp"
  port                = 8117
  interval_in_seconds = 5
  number_of_probes    = 2
}

##########################################
############### LB Rules  ################
##########################################

# LB rule Web inbound
resource "azurerm_lb_rule" "lbwebrule" {
  resource_group_name            = azurerm_resource_group.rg2.name
  loadbalancer_id                = azurerm_lb.vmssext.id
  name                           = "web"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 8081
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bpepool1.id
  frontend_ip_configuration_name = "CPVMSS-app-1"
  probe_id                       = azurerm_lb_probe.vmssprobe1.id
}

# LB rule HA ports outbound
resource "azurerm_lb_rule" "lb_haports_rule" {
  resource_group_name            = azurerm_resource_group.rg2.name
  loadbalancer_id                = azurerm_lb.vmssint.id
  name                           = "lb_haports_rule"
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bpepool2.id
  frontend_ip_configuration_name = "CPVMSS-int"
  probe_id                       = azurerm_lb_probe.vmssprobe2.id
}

##########################################
################# VMSS  ##################
##########################################

# Check Point R80.20 BYOL (blink) VMSS with AZ
resource "azurerm_virtual_machine_scale_set" "vmss" {
  name                = "CPVMSS"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg2.name
  upgrade_policy_mode = "Manual"
  zones               = [1, 2]

  plan {
    name      = "sg-byol"
    product   = "check-point-cg-r8020-blink-v2"
    publisher = "checkpoint"
  }

  sku {
    name     = "Standard_D2_v2"
    tier     = "Standard"
    capacity = 0
  }

  storage_profile_image_reference {
    publisher = "checkpoint"
    offer     = "check-point-cg-r8020-blink-v2"
    sku       = "sg-byol"
    #   version   = "8020.900005.0436"
    version = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  # storage_profile_data_disk {
  #   lun          = 0
  #   caching        = "ReadWrite"
  #   create_option  = "Empty"
  #   disk_size_gb   = 100
  # }

  # For Check Point user notused must be used
  os_profile {
    computer_name_prefix = "cpvmss"
    admin_username       = "notused"
    admin_password       = var.admin_password

    # formatting is crucial here. Do not change
    custom_data = <<-EOF
#!/usr/bin/python /etc/cloud_config.py

installationType = vmss \
allowUploadDownload = True \
osVersion = R80.20 \
templateName = vmss-v2 \
isBlink = True \
templateVersion = 20190320 \
bootstrapScript64 = "${var.bootstrap}" \
location = "${var.location}" \
sicKey = "${var.sickey}" \
vnet = "${var.hub_cidr}"
EOF

  }

  # For Check Point user notused must be used
  os_profile_linux_config {
    disable_password_authentication = false
    ssh_keys {
      path = "/home/notused/.ssh/authorized_keys"
      key_data = var.ssh_key
    }
  }

  # External interface with Public IP
  network_profile {
    name = "eth0"
    primary = true
    accelerated_networking = "true"
    ip_forwarding = "true"
    network_security_group_id = azurerm_network_security_group.vmssnsg.id

    ip_configuration {
      name = "ipconfig1"
      subnet_id = azurerm_subnet.sub3.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool1.id]
      primary = true

      public_ip_address_configuration {
        name = "instancePublicIP"
        idle_timeout = 15
        domain_name_label = "testvmss"
      }
    }
  }

  # Internal interface
  network_profile {
    name = "eth1"
    primary = false
    accelerated_networking = "true"
    ip_forwarding = "true"
    network_security_group_id = azurerm_network_security_group.vmssnsg.id

    ip_configuration {
      name = "ipconfig2"
      subnet_id = azurerm_subnet.sub4.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool2.id]
      primary = false
    }
  }

  # Defines parameters for autoprovision
  tags = {
    x-chkp-anti-spoofing = "eth0:false,eth1:false"
    x-chkp-ip-address = "public"
    x-chkp-management = var.management
    x-chkp-management-interface = "eth0"
    x-chkp-srcImageUri = "noCustomUri"
    x-chkp-template = var.template
    x-chkp-topology = "eth0:external,eth1:internal"
    environment = "vmss"
  }
}

##########################################
######### VMSS Autscale settings #########
##########################################

resource "azurerm_monitor_autoscale_setting" "test" {
  name = "myAutoscaleSetting"
  resource_group_name = azurerm_resource_group.rg2.name
  location = var.location
  target_resource_id = azurerm_virtual_machine_scale_set.vmss.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 2
      minimum = 2
      maximum = 2
    }

    rule {
      metric_trigger {
        metric_name = "Percentage CPU"
        metric_resource_id = azurerm_virtual_machine_scale_set.vmss.id
        time_grain = "PT1M"
        statistic = "Average"
        time_window = "PT5M"
        time_aggregation = "Average"
        operator = "GreaterThan"
        threshold = 80
      }

      scale_action {
        direction = "Increase"
        type = "ChangeCount"
        value = "1"
        cooldown = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name = "Percentage CPU"
        metric_resource_id = azurerm_virtual_machine_scale_set.vmss.id
        time_grain = "PT1M"
        statistic = "Average"
        time_window = "PT5M"
        time_aggregation = "Average"
        operator = "LessThan"
        threshold = 60
      }

      scale_action {
        direction = "Decrease"
        type = "ChangeCount"
        value = "1"
        cooldown = "PT5M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator = true
      send_to_subscription_co_administrator = true
      custom_emails = ["var.notify_email"]
    }
  }
}