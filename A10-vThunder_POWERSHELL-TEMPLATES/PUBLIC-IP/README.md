### PowerShell Public IP Template
This template deploys 2 Public IPs for Thunder management interface and 1 for VIP.


**Files**

    1. PS_TMPL_PUBLIC_IP_PARAM.json file contains default configuration values for Public IP resources. This file is used in CLI deployment, and users can update it as needed.
    2. PS_TMPL_PUBLIC_IP.ps1 PowerShell script to create resources on Azure Cloud.
       

**Requirements**

    1. PowerShell Version 7.2 LTS
	   https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2
	    
    2. Set execution policy to Unrestricted (only for windows machine)
        PS C:\Users\TestUser\Templates> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
        
        For more information : see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell

    3. Azure CLI installation
	   https://azcliprod.blob.core.windows.net/msi/azure-cli-2.24.0.msi

    4. Install Azure az module
	   https://www.powershellgallery.com/packages/Az/8.2.0


**Execution Step** 

**How to deploy Thunder instance using PowerShell template with PowerShell CLI** 

Navigate to the PowerShell template directory which needs to be applied and follow the below steps.

1. Open the PS_TMPL_PUBLIC_IP_PARAM.json parameter file with a text editor.
2. Configure the parameters as appropriate.
3. Verify if all the configurations in the PS_TMPL_PUBLIC_IP_PARAM.json parameter file are correct and then save the changes.
4. From the Start menu, open PowerShell and navigate to the folder where you have downloaded the PowerShell template.
5. Run the following command to create an Azure deployment group:

    ```PS C:\Users\TestUser\Templates>.\PS_TMPL_PUBLIC_IP.ps1 -resourceGroup <resource_group_name> -location "<location_name>"```

6. Verify if all the above-listed resources are created in the Home > Azure services > Resource Groups > <resource_group_name>.

        
        
    
    

