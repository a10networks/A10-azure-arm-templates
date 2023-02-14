**Files:**

    1. ARM_TMPL_3NIC_2VM_1.json
        ARM template to create 3 NIC 2 vThunder instances.
    2. ARM_TMPL_3NIC_2VM_PARAM.json
        Parameter file for ARM template.
    3. ARM_TMPL_3NIC_2VM_AUTOMATION_ACCOUNT_2.ps1
        Powershell script to create automation account and variables.
    4. ARM_TMPL_3NIC_2VM_AUTOMATION_ACCOUNT_PARAM.json
        Parameter file for automation account arm template.
    5. ARM_TMPL_3NIC_2VM_HA_GLM_CHANGE_PASSWORD_3.ps1
        Powershell script to change password of vthunder.
    6. ARM_TMPL_3NIC_2VM_WEBHOOK_4.ps1
        Powershell script to create and run SLB webhook.
    7. ARM_TMPL_3NIC_2VM_SLB_CONFIG_5.ps1
        PowerShell script to configure vThunder instances as a SLB 
    8. ARM_TMPL_3NIC_2VM_SLB_CONFIG_PARAM.json
        Parameter file for SLB
    9. ARM_TMPL_3NIC_2VM_HA_CONFIG_6.ps1
        PowerShell script to enable HA between 2 vThunder instances
    10. ARM_TMPL_3NIC_2VM_HA_CONFIG_PARAM.json
        Parameter file for HA
    11.  ARM_TMPL_3NIC_2VM_GLM_CONFIG_7.ps1
        Powershell script to apply GLM license on both vthunder instances
    12. ARM_TMPL_3NIC_2VM_GLM_CONFIG_PARAM.json
        Parameter file for GLM
    13. ARM_TMPL_3NIC_2VM_SLB_SERVER_RUNBOOK.ps1
        PowerShell script for runbook

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

    1. deploy ARM template to create 2 vThunder 3 NIC architecture
        az deployment group create --resource-group <resource-group-name> --template-file ARM_TMPL_3NIC_2VM_1.json --parameters ARM_TMPL_3NIC_2VM_PARAM.json
    2. Run script to create automation account and variables
        .\ARM_TMPL_3NIC_2VM_AUTOMATION_ACCOUNT_2.ps1
    3. Run script to change password
        .\ARM_TMPL_3NIC_2VM_HA_GLM_CHANGE_PASSWORD_3.ps1
    4. Run script to create webhook
        .\ARM_TMPL_3NIC_2VM_WEBHOOK_4.ps1
    5. Run script to configure vThunders as SLB
       .\ARM_TMPL_3NIC_2VM_SLB_CONFIG_5.ps1
    6. Run script to enable HA between 2 vThunder instances
       .\ARM_TMPL_3NIC_2VM_HA_CONFIG_6.ps1
    7. Run script to apply GLM license on both vthunder instances
       .\ARM_TMPL_3NIC_2VM_GLM_CONFIG_7.ps1