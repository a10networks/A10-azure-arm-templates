# A10’s Azure ARM/PowerShell Templates Introduction

Welcome to Azure ARM/PowerShell 1.2.0 Latest Version.

Thunder® ADCs (Application Delivery Controllers) are high-performance solutions to accelerate and optimize critical applications to ensure delivery and reliability.

ARM/PowerShell template is a custom template to create and configure Thunder using ARM[.json] and PowerShell[.ps1] scripts.

This template contains several configurations of Thunder which can be applied via box examples provided. ARM/PowerShell templates will install Thunder in the Azure cloud environment and configure the Thunder via aXAPI.


## Support Matrix

|     ACOS ADC     | [ARM/PS 1.0.0](https://github.com/a10networks/A10-azure-arm-templates/tree/release/v1.0.0) | [ARM/PS 1.1.0](https://github.com/a10networks/A10-azure-arm-templates/tree/release/v1.1.0) | [ARM/PS 1.2.0](https://github.com/a10networks/A10-azure-arm-templates/tree/release/v1.2.0) |
|:----------------:|:------------------------------------------------------------------------------------------:|:------------------------------------------------------------------------------------------:|:------------------------------------------------------------------------------------------:|
| `ACOS 6.0.1`     |                                           `No`                                            |                                           `Yes`                                            |                                           `Yes`                                            |
| `ACOS 6.0.0-p2`  |                                           `No`                                            |                                           `Yes`                                            |                                            `Yes`                                            |
| `ACOS 6.0.0-p1`  |                                           `No`                                            |                                            `Yes`                                            |                                           `Yes`                                            |
| `ACOS 5.2.1-p6`  |                                           `Yes`                                            |                                           `Yes`                                            |                                           `Yes`                                            |
| `ACOS 5.2.1-p5`  |                                           `Yes`                                            |                                           `Yes`                                            |                                           `Yes`                                            |
| `ACOS 5.2.1-p4`  |                                           `Yes`                                            |                                            `Yes`                                            |                                           `Yes`                                            |
| `ACOS 5.2.1-p3`  |                                           `Yes`                                            |                                            `Yes`                                            |                                           `Yes`                                            |


## Release Logs

## ARM/PowerShell-1.2.0

- Added support for ACOS 5.2.1-P8, ACOS 6.0.1 and ACOS 6.0.2.
- Separated the deployment and configuration parameters to ensure a clear distinction between the resources needed for initial deployment and those required for subsequent configuration and customization.
- Introduced two new SLB templates, SLB HTTP and Persist Cookie to enhance the functionality and performance of the Server Load Balancer (SLB) by optimizing HTTP traffic distribution and implementing efficient cookie persistence.
- Added support for Accelerated Networking and IP Forwarding to provide enhanced networking capabilities and improved performance. 
- Added support for Thunder Observability Agent (TOA) to collect, process and publish Thunder metrics and syslogs.
- Added new hybrid cloud GSLB configuration to optimize performance, reliability, and ease of use in hybrid cloud environments.
- Added the following deployment templates:
  1. A10-vThunder-2NIC-1VM
  2. A10-vThunder-3NIC-2VM-PUBVIP
  3. A10-vThunder-3NIC-2VM-PVTVIP
  4. A10-vThunder-3NIC-3VM
  5. A10-vThunder-3NIC-VMSS
  6. PUBLIC-IP
  7. VNET-SUBNET-NSG


- Added the following configurations for each of the templates:
  1. BASIC-SLB 
  2. CHANGE-PASSWORD 
  3. CONFIG-SLB_ON_BACKEND-AUTOSCALE 
  4. GLM-LICENSE 
  5. HIGH-AVAILABILITY 
  6. HYBRID-CLOUD-GSLB 
  7. SSL-CERTIFICATE


## ARM/PowerShell-1.1.0

- Added support for ACOS 5.2.1-P7, ACOS 6.0.0-P1 and ACOS 6.0.0-P2
- Added Thunder password change capability.
- Added the following deployment templates:
  1. A10-vThunder_ADC-2NIC-1VM 
  2. A10-vThunder_ADC-2NIC-1VM-GLM 
  3. A10-vThunder_ADC-3NIC-2VM-HA 
  4. A10-vThunder_ADC-3NIC-2VM-PVTVIP 
  5. A10-vThunder_ADC-3NIC-2VM-PUBVIP 
  6. A10-vThunder_ADC-3NIC-VMSS 
  7. A10-vThunder_ADC-3NIC-6VM-2RG-GSLB 


- Added the following configurations for each of the templates:
  1. Password Change 
  2. SSL Certificate 
  3. GLM License 
  4. Server Load Balancer 
  5. High Availability


## ARM/PowerShell-1.0.0

- Thunder infra setup with different features and combinations.
- Added support for ACOS 5.2.1-P6
- Added GLM, HA, SLB, and SSL Thunder configuration.
- Added the following deployment templates:
  1. A10-vThunder_ADC-2NIC-1VM-GLM 
  2. A10-vThunder_ADC-2NIC-1VM 
  3. A10-vThunder_ADC-3NIC-2VM-HA-GLM-PUBVIP-BACKAUTO 
  4. A10-vThunder_ADC-3NIC-2VM-HA-GLM-PVTVIP 
  5. A10-vThunder_ADC-3NIC-2VM-HA 
  6. A10-vThunder_ADC-3NIC-6VM-2RG-GSLB 
  7. A10-vThunder_ADC-3NIC-VMSS
 

## Pre-requisite

To deploy Thunder on Azure cloud using ARM/PowerShell Template, you must ensure the following prerequisites are met:

1. Download A10 Custom ARM Templates from here (https://github.com/a10networks/A10-azure-arm-templates). 
2. Azure account for sufficient permissible role. Please refer here (http://techpubs.a10networks.com/IaC/ARM_Powershell/1_2_0/html/ARM_TEMP_Responsive_HTML5/Content/ARMTOC/ListofCustomRolePermissions.htm).
3. Access [Azure Portal](https://portal.azure.com/#create/Microsoft.Template) to create Thunder virtual machine using ARM templates from the Azure Portal console.
4. Download and install [Azure CLI](https://azcliprod.blob.core.windows.net/msi/Azure-cli-2.39.0.msi) to create Thunder virtual machine using ARM templates from the Azure CLI command prompt.
For more information, see [Install Azure CLI on PowerShell](http://techpubs.a10networks.com/IaC/ARM_Powershell/1_2_0/html/ARM_TEMP_Responsive_HTML5/Content/ARMTOC/Install_AzureCLI.htm#Before).
5. Download and install [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2) to configure Thunder from powershell command prompt.
For more information, see [Install PowerShell](http://techpubs.a10networks.com/IaC/ARM_Powershell/1_2_0/html/ARM_TEMP_Responsive_HTML5/Content/ARMTOC/Install_PowerShell.htm#Before).
6. Sign up [here](https://www.a10networks.com/products/vthunder-trial/) to get Thunder Trial license.


## How it works

   1. Install PowerShell on your local OS, Please refer below sections for more details. 
   2. Install Azure Cli on your PowerShell, Please refer below sections for more details.
   3. Execute ARM/PowerShell scripts to deploy Thunder on Azure cloud, Please refer below sections for more details.
   4. Execute PowerShell scripts to apply Thunder configuration, Please refer below sections for more details.
   6. Verify Thunder configuration after the PowerShell is applied, Please refer to the below sections for more details.


## How to install PowerShell on Windows:

    1. Download Windows installable from:
        https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2
        https://github.com/PowerShell/PowerShell/releases/download/v7.2.13/PowerShell-7.2.13-win-x64.msi
        https://github.com/PowerShell/PowerShell/releases/download/v7.2.13/PowerShell-7.2.13-win-x86.msi

    2. Run the C://Downloads/PowerShell-7.2.13-win-x64 file.

    For more information, please visit: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2#installing-the-msi-package


## How to install PowerShell on Ubuntu:

    1. Download Ubuntu executable package:
        https://github.com/PowerShell/PowerShell/releases/download/v7.2.13/powershell-lts_7.2.13-1.deb_amd64.deb

    2. Execute the below commands on your machine to install PowerShell.
        a. Install the downloaded package
            sudo dpkg -i powershell-lts_7.2.13-1.deb_amd64.deb

        b. Resolve missing dependencies and finish the install (if necessary)
            sudo apt-get install -f
        
    3. Verify installation using the below command:
        a.	powershell -version

    For more information, please visit: https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu?view=powershell-7.2


## How to Install PowerShell on MacOS:

    1. Download MacOS executable package:
        https://github.com/PowerShell/PowerShell/releases/download/v7.2.13/powershell-7.2.13-osx-x64.pkg
        https://github.com/PowerShell/PowerShell/releases/download/v7.2.13/powershell-7.2.13-osx-arm64.pkg

    2. sudo installer -pkg powershell-7.3.6-osx-x64.pkg -target /

    For more information, please visit: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-macos?view=powershell-7.2


## How to Install Azure CLI on PowerShell:

    1. Execute the below commands on your PowerShell to install Azure CLI:
        ```$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://azcliprod.blob.core.windows.net/msi/azure-cli-2.51.0.msi -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; Remove-Item .\AzureCLI.msi```

    For more information, please visit: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=powershell#install-or-update


## How to deploy Thunder instance using an ARM template with Azure console 

Navigate to the ARM template directory which needs to be applied and follow the below steps.

1. From Azure Portal > Azure services, click Deploy a custom template.
2. Under Custom deployment window > Select a template tab, click Build your own template in the editor.
3. From the Edit template window, click Load file to upload the ARM template from your local machine or paste the content of the file into the editor. For example "ARM_TMPL_2NIC_1VM.json".
4. Click Save.
5. Select an existing or create a new Resource group under which you want to deploy the custom template resources.
6. Update the default values and provide the values in the empty fields as appropriate in the Instance details section.
7. Click Review+create.
8. Click Create.
9. Verify if all the above-listed resources are created in the Home > Azure services > Resource Groups > <resource_group_name>.


## How to deploy Thunder instance using an ARM template with PowerShell CLI 

Navigate to the ARM template directory which needs to be applied and follow the below steps.

1. Open the parameters file with a text editor. For example ARM_TMPL_2NIC_1VM_PARAM.json.
2. Configure the parameters as appropriate.
3. Verify if all the configurations in the ARM file are correct and then save the changes. For example ARM_TMPL_2NIC_1VM_PARAM.json.
4. From the Start menu, open PowerShell and navigate to the folder where you have downloaded the ARM template.
5. Run the following command to create an Azure resource group:

    ```PS C:\Users\TestUser\Templates>az group create --name <resource_group_name> --location "<location_name>"```

6. Run the following command to create an Azure deployment group.

    ```PS C:\Users\TestUser\Templates>az deployment group create -g <resource_group_name> --template-file <template_name> --parameters <param_template_name>```

7. Verify if all the above-listed resources are created in the Home > Azure services > Resource Groups > <resource_group_name>.


## How to deploy Thunder instance using PowerShell template with PowerShell CLI 

Navigate to the PowerShell template directory which needs to be applied and follow the below steps.

1. Open the parameters file with a text editor. For example PS_TMPL_2NIC_1VM_PARAM.json.
2. Configure the parameters as appropriate.
3. Verify if all the configurations in the parameter file are correct and then save the changes. For example PS_TMPL_2NIC_1VM_PARAM.json.
4. From the Start menu, open PowerShell and navigate to the folder where you have downloaded the PowerShell template.
5. Run the following command to create an Azure deployment group:

    ```PS C:\Users\TestUser\Templates>.\<template_name> -resourceGroup <resource_group_name> -location "<location_name>"```

6. Verify if all the above-listed resources are created in the Home > Azure services > Resource Groups > <resource_group_name>.


## How to execute Thunder Configuration from PowerShell CLI

Navigate to the PowerShell script directory which needs to be applied and follow the below steps.

1. From the Start menu, open PowerShell and navigate to the A10-vThunder-ADC-CONFIGURATION folder.
2. Run the following command from the PowerShell prompt:
    
    ```PS C:\Users\TestUser\A10-vThunder_ADC-CONFIGURATION\<CONFIGURATION-FOLDER>>.\<powershell-script-name>```


## How to verify configuration on Thunder

To verify the applied configuration, follow the below steps:

  1. SSH into the Thunder device using your username and password.
  2. Once connected, enter the following commands:

     1. `enable`

        ![image](https://github.com/smundhe-a10/terraform-provider-thunder/assets/107971633/7e532cee-fa8e-4af7-aa50-da56a24dd4c3)

     2. `show running-config`

        ![image](https://github.com/smundhe-a10/terraform-provider-thunder/assets/107971633/ae37e53d-c650-43f0-b71f-2416f4e5d65a)
     

## How to contribute

If you have created a new example, please save the ARM/PowerShell file with a resource-specific name, such as "ARM_TMPL_2NIC_1VM.json" and "ARM_TMPL_2NIC_1VM_PARAM.json"

1. Clone the repository.
2. Copy the newly created file and place it under the /examples/resource directory.
3. Create an MR against the master branch.


## Documentation

A10 Azure ARM/PowerShell template documentation is available below location, 
- ARM : https://documentation.a10networks.com -> Infrastructure as Code (IAC) -> ARM
- PS  : https://documentation.a10networks.com -> Infrastructure as Code (IAC) -> Powershell


## Report an Issue

Please raise the issue in the GitHub repository.
Please include the Azure ARM/PowerShell script that demonstrates the bug and the command output and stack traces will be helpful.


## Support

Please reach out at support@a10networks.com with "a10-azure-ARM-templates" in the subject line.