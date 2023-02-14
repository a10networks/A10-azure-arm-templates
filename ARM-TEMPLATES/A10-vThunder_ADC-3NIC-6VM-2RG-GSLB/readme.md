**Files:**

    1. ARM_TMPL_GSLB_1.json
        ARM template to create 6 vThunder instances.
    2. ARM_TMPL_GSLB_PARAM.json
        Parameter file for ARM template.
    3. ARM_TMPL_GSLB_CHANGE_PASSWORD_2.ps1
        Powershell script to create automation account and variables.
    4. ARM_TMPL_GSLB_CONFIG_3.ps1
        PowerShell script to configure vThunder instances as a SLB 
    5. ARM_TMPL_GSLB_SLB_PARAM.json
        Parameter file for SLB

**Requirements:**

    1. PowerShell Version 7.2 LTS
	   https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2
	   
    2. Install Azure az module
	   https://www.powershellgallery.com/packages/Az/8.3.0
	   
    3. Set execution policy to Unrestricted (only for windows machine)
       https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell
    
	4. Access of a10 GLM account 
	   https://glm.a10networks.com/ 
	   
	5. Azure CLI installation
	   https://azcliprod.blob.core.windows.net/msi/azure-cli-2.24.0.msi

**Execution Step - ARM Template and powershell scripts**

    1. deploy ARM template to create 6 vThunder GSLB
        az deployment group create --resource-group <resource-group-name> --template-file ARM_TMPL_GSLB_1.json --parameters ARM_TMPL_GSLB_PARAM.json
    2. Run script to change password.
        .\ARM_TMPL_GSLB_CHANGE_PASSWORD_2.ps1
    3. Run script to configure vThunders as GSLB
        .\ARM_TMPL_GSLB_CONFIG_3.ps1
