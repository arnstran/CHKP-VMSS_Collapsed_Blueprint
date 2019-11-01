# CHKP-VMSS_Collapsed_Blueprint
Deploys a collapsed Check Point Cloud Security Blueprint in Azure using Terraform with a CloudGuard IaaS Scale Set in one hub (used for inbound and outbound traffic).
Public accessible Jumphost in East spoke and a public load balanced web site (2 x Web servers) in West spoke.

Requirements:
- Terraform installed on a machine (Terraform version 0.11.15 tested. 0.12 needs 'terraform 0.12upgrade' after the 'terraform init')
        - Can also run from Azure CLI (which use terraform version 0.12.x)
- Azure AD and Service Principal created (https://sc1.checkpoint.com/documents/IaaS/WebAdminGuides/EN/CP_VMSS_for_Azure/212075.htm)
	- If not running from Azure CLI, add credentials in variable file, or better as Environment Variables on the host
		
		Example added to the end of .bashrc on your host
		
			export ARM_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx"
			
			export ARM_CLIENT_SECRET="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
			
			export ARM_SUBSCRIPTION_ID="xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
			
			export ARM_TENANT_ID="xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
			
- An existing R80.30 Check Point Management (https://sc1.checkpoint.com/documents/IaaS/WebAdminGuides/EN/CP_VMSS_for_Azure/212112.htm)
    - prepared with autoprovision (CME is prefered over autoprov-cfg), and a policy for the VMSS's (https://sc1.checkpoint.com/documents/IaaS/WebAdminGuides/EN/CP_VMSS_for_Azure/212077.htm)
	- See documentation for more details
    https://sc1.checkpoint.com/documents/IaaS/WebAdminGuides/EN/CP_VMSS_for_Azure/html_frameset.htm


Notes:
- Management server communicate with gateways over public IPs
- R80.30 gateways will be deployed


Run:
Before you run the templates, variables.tf needs to be updated. At least password, SIC key and SSH key. And make sure relevant variables (management and template) matches your Management server autoprovision configuration that you did above.

Put the files in a directory (download or git clone) on your host (the host where terraform is installed), and from that directory run:
'terraform init'
'terraform 0.12upgrade' (only if terraform version 0.12 is used)
'terraform plan' (optional)
'terraform apply'


Testing:
When the deployment finishes, it prints the IP of the Jumphost and the domain of the web application 
- When the deployment finished it still takes 5-10 minutes for all the Check Point autoprovison to finish.
- Test inbound by browsing to the domain from your client
- Test between spokes (E/W) by SSH'ing to the Jumphost (user:ubuntu and need to use SSH key for authentication) and pinging one of the web servers
- Test outbound by SSH'ing to one of the web servers from the Jumphost (user:ubuntu and need to use SSH key for authentication to login to the web servers), and ping 8.8.8.8
- Verify logs in SmartConsole


Stop/destroy:
When finished, stop instances or run 'terraform destroy' to remove the deployment


Known issues:
- You might need to ask Microsoft to increase your Dv2 quota
- Sometimes 'terraform destroy' fails. A rerun or two fixes it.
