##########################################
######### Internal LB in West  ###########
##########################################

# Internal Web Load Balancer
resource "azurerm_lb" "webint" {
 name                = "web-lb"
 location            = "${var.location}"
 resource_group_name = "${azurerm_resource_group.rg1.name}"
 sku				 = "Standard"

 frontend_ip_configuration {
   name                 = "Web-int"
   subnet_id			= "${azurerm_subnet.sub1.id}"
   private_ip_address	= "${cidrhost(azurerm_subnet.sub1.address_prefix, 200)}"
   private_ip_address_allocation = "Static"
 }

 tags = "${var.envtags}"
}

##########################################
########### LB Backend pool  #############
##########################################

# Backend pool for Internal LB
resource "azurerm_lb_backend_address_pool" "bpepool3" {
 resource_group_name = "${azurerm_resource_group.rg1.name}"
 loadbalancer_id     = "${azurerm_lb.webint.id}"
 name                = "WebAddressPool"
}

##########################################
############## LB Probes  ################
##########################################

# LB probe for Internal LB
resource "azurerm_lb_probe" "webprobe3" {
 resource_group_name = "${azurerm_resource_group.rg1.name}"
 loadbalancer_id     = "${azurerm_lb.webint.id}"
 name                = "web-probe"
 protocol			 = "Http"
 request_path		 = "/"
 port                = 80
 interval_in_seconds = 5
 number_of_probes	 = 2
}

##########################################
############### LB Rules  ################
##########################################

# LB rule Web inbound
resource "azurerm_lb_rule" "lbwebintrule" {
   resource_group_name            = "${azurerm_resource_group.rg1.name}"
   loadbalancer_id                = "${azurerm_lb.webint.id}"
   name                           = "web-int"
   protocol                       = "Tcp"
   frontend_port                  = 80
   backend_port                   = 80
   backend_address_pool_id        = "${azurerm_lb_backend_address_pool.bpepool3.id}"
   frontend_ip_configuration_name = "Web-int"
   probe_id                       = "${azurerm_lb_probe.webprobe3.id}"
}
