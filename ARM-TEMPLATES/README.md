# A10 Networks Azure Resource Manager (ARM) Templates Release v1.0.0
Azure ARM templates can be deployed through the Azure Command lines (CLI).

- **Azure CLI**<br>
The pre-requisite to using this option is to download the scripts first by the user, customise certain parameters
like resource group, VM name, network etc before pasting the script’s content on either Azure CLI. 
For more information on using this option please refer to Azure documentation: https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-deploy-portal

# A10’s ARM Template Information
A10’s ARM templates listed here are for deploying vThunder ADC (Application Delivery Controller) System 
in different design and configuration namely:

- Deploying vThunder ADC in Azure- 2 NICs(1 Management + 1 Data) - 1 VM **<br>
      - *BYOL(Bring Your Own License)*<br>
      - *1 VM*<br>
      - *SLB (vThunder Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
- Deploying vThunder ADC in Azure- 2 NICs(1 Management + 1 Data) - 1 VM - GLM**<br>
      - *BYOL(Bring Your Own License)*<br>
      - *1 VM*<br>
      - *SLB (vThunder Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
      - *GLM (Auto apply A10 license)*<br>
- Deploying vThunder ADC in Azure- 3 NICs(1 Management + 2 Data) - 2VM - HA**<br>
      - *BYOL(Bring Your Own License)*<br>
      - *2 VM*<br>
      - *HIGH AVAILABILITY (Auto swithover with another available VM)*<br>
      - *SLB (vThunder Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
- Deploying vThunder ADC in Azure- 3 NICs(1 Management + 2 Data) - 2VM - HA - GLM - PVTVIP**<br>
      - *BYOL(Bring Your Own License)*<br>
      - *2 VM*<br>
      - *HIGH AVAILABILITY (Auto swithover with another available VM)*<br>
      - *VIP (Private Interface)*<br>
      - *SLB (vThunder Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
      - *GLM (Auto apply A10 license using global license manager)*<br>
- Deploying vThunder ADC in Azure- 3 NICs(1 Management + 2 Data) - 2 VM - HA - GLM - PUBVIP - BACKAUTO**<br>
      - *BYOL(Bring Your Own License)*<br>
      - *2 VM*<br>
      - *HIGH AVAILABILITY (Auto swithover with another available VM)*<br>
      - *VIP (Public Interface)*<br>
      - *BACKEND SERVER AUTOSCALE (Webhook to configure vThunder on web servers auto scaling)*<br>
      - *GLM (Auto apply A10 license using global license manager)*<br>
      - *SLB (vThunder Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
- Deploying vThunder ADC in Azure- 3 NICs(1 Management + 2 Data) - NVM - VMSS**<br>
      - *BYOL(Bring Your Own License)*<br>
      - *UNLIMITED Numberes of VMs*<br>
      - *VMSS (Virtual Machine Scale Set - vThunder autoscaling using metrics and rules)*<br>
      - *GLM (Auto apply A10 license using global license manager)*<br>
      - *SLB (vThunder Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
      - *AZURE ANALYTICS (Azure log monitoring using azure log analytics service)*<br>
      - *AZURE INSIGHT (Autoscale using custom metrics and monitoring using azure application insight service)*<br>
- Deploying vThunder ADC in Azure- 3 NICs(1 Management + 2 Data) - 6VM(Three in each region) - 2RG(Region) - GSLB**<br>
      - *BYOL(Bring Your Own License)*<br>
      - *3 VM in each region*<br>
      - *2 Region*<br>
      - *GSLB (vThunder - Global Server Load Balancer for traffic routing across region.)*<br>
	  
For more detailed documentation please refer offline documentation within repository or online documentation :
https://documentation.a10networks.com/IaC/ARM_Powershell/index.html
