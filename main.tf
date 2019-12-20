variable "awsTempAdminPassword" {}
variable "awsVpcName" {}
variable "awsSubnetSuffix" {}
variable "awsNamePrefix" {}
variable "awsSshKeyName" {}
variable "awsRegion" {}
variable "awsAmiId" {}
variable "awsInstanceType" {}

terraform {
    required_version = ">= 0.12"
}

provider "aws" {
    region                      = var.awsRegion
#    access_key                  = var.awsAccessKey
#    secret_key                  = var.awsSecretKey
}

data "aws_vpc" "lipowsky-tf-vpc" {
    tags = {
        Name                    = var.awsVpcName
    }
}

# Retrieve subnet IDs from VPC, using subnet suffix as search criteria

data "aws_subnet_ids" "awsVpcMgmtSubnet" {
    vpc_id                      = data.aws_vpc.lipowsky-tf-vpc.id
    tags = {
        Name                    = "*mgmt*${var.awsSubnetSuffix}"
    }
}

data "aws_subnet_ids" "awsVpcExternalSubnet" {
    vpc_id                      = data.aws_vpc.lipowsky-tf-vpc.id
    tags = {
        Name                    = "*external*${var.awsSubnetSuffix}"
    }
}

data "aws_subnet_ids" "awsVpcInternalSubnet" {
    vpc_id                      = data.aws_vpc.lipowsky-tf-vpc.id
    tags = {
        Name                    = "*internal*${var.awsSubnetSuffix}"
    }
}

# Retrieve security group IDs from VPC

data "aws_security_groups" "awsVpcMgmtSecurityGroup" {
    filter {
        name                    = "vpc-id"
        values                  = ["${data.aws_vpc.lipowsky-tf-vpc.id}"]
    }
    tags = {
        Name                    = "*mgmt*"
    }
}

data "aws_security_groups" "awsVpcExternalSecurityGroup" {
    filter {
        name                    = "vpc-id"
        values                  = ["${data.aws_vpc.lipowsky-tf-vpc.id}"]
    }
    tags = {
        Name                    = "*external*"
    }
}

data "aws_security_groups" "awsVpcInternalSecurityGroup" {
    filter {
        name                    = "vpc-id"
        values                  = ["${data.aws_vpc.lipowsky-tf-vpc.id}"]
    }
    tags = {
        Name                    = "*internal*"
    }
}

# Create ENIs in each of the above subnets & assign security group

resource "aws_network_interface" "mgmt-enis" {
    count                       = 2
    subnet_id                   = tolist(data.aws_subnet_ids.awsVpcMgmtSubnet.ids)[0]
    security_groups             = data.aws_security_groups.awsVpcMgmtSecurityGroup.ids
    tags = {
        Name                    = "${var.awsNamePrefix}-bigip-${count.index+1}-${var.awsSubnetSuffix}-eth0"
    }
}

resource "aws_network_interface" "external-enis" {
    count                       = 2
    subnet_id                   = tolist(data.aws_subnet_ids.awsVpcExternalSubnet.ids)[0]
    security_groups             = data.aws_security_groups.awsVpcExternalSecurityGroup.ids
    tags = {
        Name                    = "${var.awsNamePrefix}-bigip-${count.index+1}-${var.awsSubnetSuffix}-eth1"
    }
}

resource "aws_network_interface" "internal-enis" {
    count                       = 2
    subnet_id                   = tolist(data.aws_subnet_ids.awsVpcInternalSubnet.ids)[0]
    security_groups             = data.aws_security_groups.awsVpcInternalSecurityGroup.ids
    tags = {
        Name                    = "${var.awsNamePrefix}-bigip-${count.index+1}-${var.awsSubnetSuffix}-eth2"
    }
}

# Create EIPs for management ENIs

resource "aws_eip" "mgmt-eips" {
    count                       = 2
    network_interface           = aws_network_interface.mgmt-enis[count.index].id
    vpc                         = true
}

# Create EIPs for external ENIs

resource "aws_eip" "external-eips" {
    count                       = 2
    network_interface           = aws_network_interface.external-enis[count.index].id
    vpc                         = true
}

# Create 2x F5 BIG-IP instances

resource "aws_instance" "f5_bigip" {
    count                       = 2
    instance_type               = var.awsInstanceType
    ami                         = var.awsAmiId
    key_name                    = var.awsSshKeyName
    network_interface {
        network_interface_id       = aws_network_interface.mgmt-enis[count.index].id
        device_index            = 0
    }
    network_interface {
        network_interface_id       = aws_network_interface.external-enis[count.index].id
        device_index            = 1
    }
    network_interface {
        network_interface_id       = aws_network_interface.internal-enis[count.index].id
        device_index            = 2
    }
    tags = {
        Name                    = "${var.awsNamePrefix}-bigip-${count.index+1}-${var.awsSubnetSuffix}"
    }
    user_data = <<-EOF
        #! /bin/bash
        /bin/tmsh modify sys management-dhcp sys-mgmt-dhcp-config request-options delete { host-name domain-name }
        /bin/tmsh modify auth user admin password ${var.awsTempAdminPassword}
        /bin/tmsh save sys config
        echo "cloud-init finished" >> /config/cloud-init.output
    EOF
}