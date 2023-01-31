# A10 Networks Azure Powershell Templates Release v1.1.0
These PowerShell templates can be either deployed through the Azure PowerShell or through Command lines (CLI).

- **Azure PowerShell or Azure CLI**<br>
The pre-requisite to using this option is to download the scripts first by the user, customise certain parameters
like resource group, VM name, network etc before pasting the script’s content on either Azure PowerShell or Azure CLI. 
For more information on using this option please refer to Azure documentation: https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-deploy-portal

##Global License Manager (GLM)
For all A10 licenses, GLM (Global License Manager) is the authoritative service. 
All A10 products conform with license and licensing policies dictated by GLM. 
GLM is available at https://glm.a10networks.com. 
Default License Manager for HC is set to GLM. 
User can change this in Controller scope by logging in as Super-admin.

# A10’s Azure Powershell Template Information
A10’s Azure Powershell templates listed here are for deploying vThunder ADC (Application Delivery Controller) in different design and configuration namely:

- **Deploying vThunder ADC in Azure- 2 NICs - 1 VM (1 Management + 1 Data)**<br>
      - *BYOL(Bring Your Own License)*<br>
      - *1 VM*<br>
      - *SLB (Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
- **Deploying vThunder ADC in Azure- 2 NICs - 1 VM - GLM (1 Management + 1 Data)**<br>
      - *Global License Manager (GLM is the master licensing and billing system for A10 vThunder)*<br>
      - *1 VM*<br>
      - *SLB (Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
- **Deploying vThunder ADC in Azure- 3 NICs - 2 VM - HA (1 Management + 2 Data)**<br>
      - *BYOL(Bring Your Own License)*<br>
      - *2 VM*<br>
      - *High Availability (Auto swithover with multiple VMs)*<br>
      - *SLB (Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
- **Deploying vThunder ADC in Azure- 3 NICs - 2 VM - HA - GLM - PVTVIP (1 Management + 2 Data)**<br>
      - *2 VM*<br>
      - *High Availability (Auto swithover with multiple VMs)*<br>
      - *VIP (Private Interface)*<br>
      - *Global License Manager (GLM is the master licensing and billing system for A10 vThunder)*<br>
      - *SLB (Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
- **Deploying vThunder ADC in Azure- 3 NICs - 2 VM - HA - GLM - PUBVIP - BACKAUTO (1 Management + 2 Data)**<br>
      - *2 VM*<br>
      - *High Availability (Auto swithover with multiple VMs)*<br>
      - *VIP (Public Interface)*<br>
      - *BACKEND AUTO SCALING*<br>
      - *Global License Manager (GLM is the master licensing and billing system for A10 vThunder)*<br>
      - *SLB (Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
- **Deploying vThunder ADC in Azure - 3 NICs - NVM -VMSS (1 Management + 2 Data)**<br>
      - *UNLIMITED NUMBERS OF VM*<br>
      - *VMSS (Virtual Machine Scale Set - vThunder autoscaling using metrics and rules)*<br>
      - *Global License Manager (GLM is the master licensing and billing system for A10 vThunder)*<br>
      - *SLB (Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
      - *Log Analysis using Azure Log Analytics integration*<br>
      - *Azure Application Insight integration*<br>

For more detailed documentation please refer offline documentation within repository or online documentation :
https://documentation.a10networks.com/IaC/ARM_Powershell/index.html

## A10’s vThunder Support Information
Below listed A10’s vThunder vADC (Application Delivery Controller) are tested and supported.
- 64-bit Advanced Core OS (ACOS) version 5.2.0, build 155.
- 64-bit Advanced Core OS (ACOS) version 5.2.1-p5, build 114
- 64-bit Advanced Core OS (ACOS) version 5.2.1-p6, build 74
- 64-bit Advanced Core OS (ACOS) version 6.0.0 build 419

## Release Logs Information
- Automated script to change password after installation.
- Automated scripts to install and configure runbooks.
- Advance support for ACOS version 6.X.X.