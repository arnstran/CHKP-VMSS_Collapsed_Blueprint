# Configure the Microsoft Azure Provider

provider "azurerm" {
	version = "~> 1.36.1"
}

##########################################
########### Resource Groups  #############
##########################################

# Spoke RG
resource "azurerm_resource_group" "rg1" {
  name     = "${var.project_name}-spoke"
  location = "${var.location}"
}

# Hub RG
resource "azurerm_resource_group" "rg2" {
  name     = "${var.project_name}-hub"
  location = "${var.location}"
}

##########################################
########## Virtual Networks  #############
##########################################

# West vNet
resource "azurerm_virtual_network" "vn1" {
  name                = "${var.project_name}-West"
  address_space       = ["${var.west_cidr}"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg1.name}"
}

# East vNet
resource "azurerm_virtual_network" "vn2" {
  name                = "${var.project_name}-East"
  address_space       = ["${var.east_cidr}"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg1.name}"
}

# Hub vNet
resource "azurerm_virtual_network" "vn3" {
  name                = "${var.project_name}-Hub"
  address_space       = ["${var.hub_cidr}"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg2.name}"
}

##########################################
############# vNet Peering  ##############
##########################################

# Peering West to Hub
resource "azurerm_virtual_network_peering" "test1" {
  name                      	= "west2hub"
  resource_group_name       	= "${azurerm_resource_group.rg1.name}"
  virtual_network_name      	= "${azurerm_virtual_network.vn1.name}"
  remote_virtual_network_id 	= "${azurerm_virtual_network.vn3.id}"
  allow_virtual_network_access	= true
  allow_forwarded_traffic   	= true
}

# Peering East to Hub
resource "azurerm_virtual_network_peering" "test2" {
  name                      	= "east2hub"
  resource_group_name       	= "${azurerm_resource_group.rg1.name}"
  virtual_network_name      	= "${azurerm_virtual_network.vn2.name}"
  remote_virtual_network_id 	= "${azurerm_virtual_network.vn3.id}"
  allow_virtual_network_access	= true
  allow_forwarded_traffic   	= true
}

# Peering Hub to West
resource "azurerm_virtual_network_peering" "test3" {
  name                      	= "hub2west"
  resource_group_name       	= "${azurerm_resource_group.rg2.name}"
  virtual_network_name      	= "${azurerm_virtual_network.vn3.name}"
  remote_virtual_network_id		= "${azurerm_virtual_network.vn1.id}"
  allow_virtual_network_access	= true
  allow_forwarded_traffic   	= true
}

# Peering Hub to East
resource "azurerm_virtual_network_peering" "test4" {
  name                      	= "hub2east"
  resource_group_name       	= "${azurerm_resource_group.rg2.name}"
  virtual_network_name      	= "${azurerm_virtual_network.vn3.name}"
  remote_virtual_network_id 	= "${azurerm_virtual_network.vn2.id}"
  allow_virtual_network_access	= true
  allow_forwarded_traffic   	= true
}

##########################################
####### Subnets and Route tables #########
##########################################

# Subnet in West
resource "azurerm_subnet" "sub1" {
  name                 = "subWest"
  resource_group_name  = "${azurerm_resource_group.rg1.name}"
  virtual_network_name = "${azurerm_virtual_network.vn1.name}"
  address_prefix       = "${cidrsubnet(var.west_cidr, 8, 2)}"
}

# Subnet in East
resource "azurerm_subnet" "sub2" {
  name                 = "subEast"
  resource_group_name  = "${azurerm_resource_group.rg1.name}"
  virtual_network_name = "${azurerm_virtual_network.vn2.name}"
  address_prefix       = "${cidrsubnet(var.east_cidr, 8, 2)}"
}

# Frontend subnet in Hub
resource "azurerm_subnet" "sub3" {
  name                 = "frontend"
  resource_group_name  = "${azurerm_resource_group.rg2.name}"
  virtual_network_name = "${azurerm_virtual_network.vn3.name}"
  address_prefix       = "${cidrsubnet(var.hub_cidr, 8, 0)}"
}

# Backend subnet in Hub
resource "azurerm_subnet" "sub4" {
  name                 = "backend"
  resource_group_name  = "${azurerm_resource_group.rg2.name}"
  virtual_network_name = "${azurerm_virtual_network.vn3.name}"
  address_prefix       = "${cidrsubnet(var.hub_cidr, 8, 1)}"
}

# Route table for subnet in West
resource "azurerm_route_table" "rt1" {
  name							= "rtWest"
  location						= "${var.location}"
  resource_group_name			= "${azurerm_resource_group.rg1.name}"
  disable_bgp_route_propagation	= true

  route {
    name						= "to-Internet"
    address_prefix				= "0.0.0.0/0"
    next_hop_type				= "VirtualAppliance"
    next_hop_in_ip_address		= "${cidrhost(azurerm_subnet.sub4.address_prefix, 4)}"
  }
  route {
    name						= "to-internal-current-vnet"
    address_prefix				= "${element(azurerm_virtual_network.vn1.address_space, 0)}"
    next_hop_type				= "VirtualAppliance"
    next_hop_in_ip_address		= "${cidrhost(azurerm_subnet.sub4.address_prefix, 4)}"
  }
  route {
    name						= "to-internal-other-vnet"
    address_prefix				= "${element(azurerm_virtual_network.vn2.address_space, 0)}"
    next_hop_type				= "VirtualAppliance"
    next_hop_in_ip_address		= "${cidrhost(azurerm_subnet.sub4.address_prefix, 4)}"
  }
  route {
    name						= "to-internal-current-subnet"
    address_prefix				= "${azurerm_subnet.sub1.address_prefix}"
    next_hop_type				= "vnetlocal"
  }
}

resource "azurerm_subnet_route_table_association" "rt1sub" {
  subnet_id      = "${azurerm_subnet.sub1.id}"
  route_table_id = "${azurerm_route_table.rt1.id}"
}

# Route table for subnet in West
resource "azurerm_route_table" "rt2" {
  name							= "rtEast"
  location						= "${var.location}"
  resource_group_name			= "${azurerm_resource_group.rg1.name}"
  disable_bgp_route_propagation	= false

  route {
    name						= "to-internal-current-vnet"
    address_prefix				= "${element(azurerm_virtual_network.vn2.address_space, 0)}"
    next_hop_type				= "VirtualAppliance"
    next_hop_in_ip_address		= "${cidrhost(azurerm_subnet.sub4.address_prefix, 4)}"
  }
  route {
    name						= "to-internal-other-vnet"
    address_prefix				= "${element(azurerm_virtual_network.vn1.address_space, 0)}"
    next_hop_type				= "VirtualAppliance"
    next_hop_in_ip_address		= "${cidrhost(azurerm_subnet.sub4.address_prefix, 4)}"
  }
  route {
    name						= "to-internal-current-subnet"
    address_prefix				= "${azurerm_subnet.sub2.address_prefix}"
    next_hop_type				= "vnetlocal"
  }
}

resource "azurerm_subnet_route_table_association" "rt2sub" {
  subnet_id      = "${azurerm_subnet.sub2.id}"
  route_table_id = "${azurerm_route_table.rt2.id}"
}
