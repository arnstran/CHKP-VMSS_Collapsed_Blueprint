# CHKP-VMSS_Collapsed_Blueprint
Deploys a collapsed Check Point Cloud Security Blueprint using Terraform with VMSS in one hub (inbound and outbound).
Public accessible Jumphost in West spoke and public load balanced web site (2 x Web servers) in East spoke.

Needs:
- terraform installed (version 0.11 or below tested and works, 0.12 needs 'terraform 0.12upgarde')
        - Eg. https://azurecitadel.com/prereqs/wsl/
        - or run from Azure CLI
- an existing R80.20 Check Point Management prepared with autoprovision and policy for the VMSS's
    https://sc1.checkpoint.com/documents/IaaS/WebAdminGuides/EN/CP_VMSS_for_Azure/html_frameset.htm
- If not running from Azure CLI add credentials in variable file or better as Environment Variables on the host
    Example added to the end of .bashrc on your host
        export ARM_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx"
        export ARM_CLIENT_SECRET="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        export ARM_SUBSCRIPTION_ID="xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        export ARM_TENANT_ID="xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

Notes:
- Management server communicate with gateways over public IPs

Run:
put the files in a directory on your host (download or git clone) and fron that directory run:
'terraform init'
'terraform plan' (optional)
'terrafrom apply'

Known issues:
- You probably need to ask Microsoft to increase your Dv2 quota
- sometimes the vNet peerings fail to deploy.
  Rerunning 'terraform apply' might deploy them correctly, but sometimes destroys the route table association.
  Another rerun typically fixes it
