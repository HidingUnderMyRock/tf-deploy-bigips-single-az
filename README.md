# tf-deploy-bigips-one-az

## Description

This Terraform module is used to deploy multiple F5 BIG-IPs in an AWS VPC, placing each BIG-IP into **one** availability zone and installing the declarative onboarding framework.

## Variables

### terraform.tfvars

| Variable | Description |
| -------- | ----------- |
| awsVpcName | The VPC name in AWS that the BIG-IPs will reside within |
| awsSubnetSuffix | The suffix the module will use to identify the availability zone subnets |
| awsNamePrefix | The prefix to all created objects name/tags within AWS |
| awsSshKeyName | The SSH key within the AWS region that the BIG-IPs will use to authenticate |
| awsRegion | The AWS region the VPC resides within |
| awsAmiId | The AMI ID for the BIG-IP image that will be used |
| awsInstanceType | The instance size/flavor of the BIG-IP instances |
| awsSecondaryIpCount | The number of secondary IP addresses to attach to external interface |

### cloud-init.yaml

| Variable | Description |
| -------- | ----------- |
| TEMPADMINPWD | The **temporary** admin password |
| FN | Declarative onboarding RPM filename |
| RPMURL | Download link for declarative onboarding RPM |
| FILEPATH | Path to downloaded file on BIG-IP |
| CREDS | Credentials used to install declarative onboarding |
| IP | IP address of BIG-IP instance |

## Documentation

The Terraform module has been tested with the tf-create-vpc module, and expects to find specific naming schemes in place to identify subnets and other resources.  For example, with awsSubnetSuffix set to az1, the module will query the subnets within the VPC for tags that end in az1, and for subnets that contain mgmt, external, and internal.  It will assign these subnets to the ENIs for the BIG-IP instances.

All names/tags for objects will contain the value of the awsNamePrefix variable, and be postpended with the value of the awsSubnetSuffix.  For example, with awsNamePrefix set to lipowsky-tf, and awsSubnetSuffix set to az1, the BIG-IPs will be tagged as lipowsky-tf-bigip-1-az1 and lipowsky-tf-bigip-2-az1.

No further licensing or configuration of the BIG-IP instances is performed.  It is expected that Declarative Onboarding will be used to configure and license the BIG-IP instances, in preparation for service deployment.

[Declarative Onboarding](https://clouddocs.f5.com/products/extensions/f5-declarative-onboarding/latest/)