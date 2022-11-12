# Deployment options for A10's Azure Powershell Templates
Azure Powershell templates can be deployed through the Powershell (CLI).

- **Azure powershell cli**<br>
The pre-requisite to using this option is to download the scripts first by the user, customise certain parameters
like resource group, VM name, network etc before pasting the script’s content on either Azure PowerShell CLI. 
For more information on using this option please refer to Azure documentation: https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-deploy-portal

# A10’s Powershell Template Information
A10’s Powershell templates listed here are for deploying vThunder ADC (Application Delivery Controller) System 
in different design and configuration namely:

- Deploying vThunder ADC in Azure- 2 NICs(1 Management + 1 Data) - 1 VM **<br>
      - *BYOL(Bring Your Own License)*<br>
      - *1 VM*<br>
      - *SLB (vThunder Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
- Deploying vThunder ADC in Azure- 2 NICs(1 Management + 1 Data) - 1 VM - GLM**<br>
      - *1 VM*<br>
      - *SLB (vThunder Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
	  - *GLM (Auto apply A10 license)*<br>
- Deploying vThunder ADC in Azure- 3 NICs(1 Management + 2 Data) - 2VM - HA**<br>
      - *BYOL(Bring Your Own License)*<br>
      - *2 VM*<br>
      - *High Availability (Auto swithover with another available VM)*<br>
      - *SLB (vThunder Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
- Deploying vThunder ADC in Azure- 3 NICs(1 Management + 2 Data) - 2VM - HA - GLM - PVTVIP**<br>
      - *2 VM*<br>
      - *High Availability (Auto swithover with another available VM)*<br>
      - *VIP (Private Interface)*<br>
      - *SLB (vThunder Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
	  - *GLM (Auto apply A10 license using global license manager)*<br>
- Deploying vThunder ADC in Azure- 3 NICs(1 Management + 2 Data) - 2 VM - HA - GLM - PUBVIP - BACKAUTO**<br>
      - *2 VM*<br>
      - *High Availability (Auto swithover with another available VM)*<br>
      - *VIP (Public Interface)*<br>
      - *Backend Auto Scaling (Configure vThunder on client servers auto scaling)*<br>
	  - *GLM (Auto apply A10 license using global license manager)*<br>
      - *SLB (vThunder Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
- Deploying vThunder ADC in Azure- 3 NICs(1 Management + 2 Data) - NVM - VMSS**<br>
      - *Unlimited Numberes of VMs*<br>
      - *VMSS (Virtual Machine Scale Set - vThunder autoscaling using metrics and rules)*<br>
	  - *GLM (Auto apply A10 license using global license manager)*<br>
      - *SLB (vThunder Server Load Balancer)*<br>
      - *SSL (SSL Certification)*<br>
      - *Log Analysis using Azure Log Analytics integration*<br>
      - *Azure Application Insight integration*<br>