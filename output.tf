##########################################
############# Outputs  ###################
##########################################

output "vmss_public_ip" {
	value = "${azurerm_public_ip.vmss-extlb.fqdn}"
	description = "The FQDN of the Frontend load balancer."
}

data "azurerm_public_ip" "jumphostip"	{
	depends_on = ["azurerm_virtual_machine.my_mgmt"]
	name = "${azurerm_public_ip.pub1.name}"
	resource_group_name = "${azurerm_resource_group.rg1.name}"
}	

output "jumphost_ip_address" {
        value = "${data.azurerm_public_ip.jumphostip.ip_address}"
        description = "The public IP address of the jumphost server instance."
}
