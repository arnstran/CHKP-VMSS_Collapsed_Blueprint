variable "project_name" {
  default = "VMSS-demo"
}

variable "location" {
  default = "northeurope"
}

# template code requires /16 and subnets will get /24
variable "hub_cidr" {
  default = "10.1.0.0/16"
}

# template code requires /16 and subnets will get /24
variable "west_cidr" {
  default = "10.40.0.0/16"
}

# template code requires /16 and subnets will get /24
variable "east_cidr" {
  default = "10.50.0.0/16"
}

# must match what was used in autoprov-cfg config
variable "management" {
  default = "mgmt"
}

# must match what was used in autoprov-cfg config
variable "template" {
  default = "vmss-template"
}

# must match what was used in autoprov-cfg config
variable "sickey" {
  default = ""
}

variable "admin_password" {
  default = ""
}

variable "ssh_key" {
  default = "ssh-rsa ......"
}

variable "notify_email" {
  default = ""
}

variable "envtags" {
  description = "A map of the tags to use for other resources that are deployed"
  type        = "map"

  default = {
    environment = "vmss"
  }
}

variable "servertags" {
  description = "A map of the tags to use for server resources that are deployed"
  type        = "map"

  default = {
    environment = "vmss"
    access = "internet"
  }
}

variable "vm_mgmt" {
  default = "Jumphost"
}

variable "vm_name1" {
  default = "Web-West01"
}

variable "vm_name2" {
  default = "Web-West02"
}

variable "bootstrap" {
  default = ""
}

variable "ubuntu_user_data" {
  default = <<-EOF
                    #!/bin/bash
                    until sudo apt-get update && sudo apt-get -y install apache2;do
                      sleep 1
                    done
                    until curl \
                      --output /var/www/html/CloudGuard.png \
                      --url https://www.checkpoint.com/wp-content/uploads/cloudguard-hero-image.png ; do
                       sleep 1
                    done
                    sudo chmod a+w /var/www/html/index.html 
                    echo "<html><head><meta http-equiv=refresh content="5" /> </head><body><center><H1>" > /var/www/html/index.html
                    echo $HOSTNAME >> /var/www/html/index.html
                    echo "<BR><BR>Check Point CloudGuard VMSS Demo <BR><BR>Any Cloud, Any App, Unmatched Security<BR><BR>" >> /var/www/html/index.html
                    echo "<img src=\"/CloudGuard.png\" height=\"25%\">" >> /var/www/html/index.html
                    EOF
}
