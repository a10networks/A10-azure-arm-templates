# A10 Networks Azure Resource Manager (ARM/POWERSHELL) Templates Release v1.0.0
Welcome to GitHub repository for A10’s ARM templates for Azure cloud. This repository hosts templates for single-click 
deployment of A10’s vThunder on Azure cloud. 

## What is Azure Resource (ARM/POWERSHELL) Template?
ARM template simplifies provisioning and management on Azure. You can create templates for the service or application 
architectures you want and have Azure Resource Manager use those templates for quick and reliable provisioning of the 
services or applications (called “stacks”). You can also easily update or replicate the stacks as needed.This collection 
of sample templates will help you get started with Azure Resource Manager and quickly build your own templates.

## Deployment options for A10's ARM templates in Azure
These ARM templates can be either deployed through the Azure Command lines CLI or Powershell CLI. 

- **Deploy to Azure**<br>
This is a single click option which takes the user can customise templates and parameters
and initiating the template deployment. 

- **Azure PowerShell or Azure CLI**<br>
The pre-requisite to using this option is to download the scripts first by the user, customise certain parameters
like resource group, VM name, network etc before pasting the script’s content on either Azure PowerShell or Azure CLI. 
For more information on using this option please refer to Azure documentation: https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-deploy-portal

## A10’s ARM Template Information
A10’s ARM templates listed here are for deploying vThunder ADC (Application Delivery Controller) in different design and configuration namely:

- Powershell templates can be found under ./POWERSHELL-TEMPLATES.
- ARM templates can be found under ./ARM-TEMPLATES.

For more detailed documentation please refer offline documentation within repository or online documentation :
https://documentation.a10networks.com/IaC/ARM_Powershell/index.html

## A10’s vThunder Support Information
Below listed A10’s vThunder vADC (Application Delivery Controller) BYOL are tested and supported.
- 64-bit Advanced Core OS (ACOS) version 5.2.1-p4.
- 64-bit Advanced Core OS (ACOS) version 5.2.1-p5.

## Release Logs Information
- vThunder infra setup with different feature and combinations.
- vThunder configuration.
