**Files:**

    1. ARM_TMPL_3NIC_2VM_1.json
        ARM template to create 3 NIC 2 vThunder instances.
    2. ARM_TMPL_3NIC_2VM_PARAM.json
        Parameter file for ARM template.
    3. ARM_TMPL_3NIC_2VM_AUTOMATION_ACCOUNT_2.ps1
        Powershell script to create automation account and variables.
    4. ARM_TMPL_3NIC_2VM_AUTOMATION_ACCOUNT_PARAM.json
        Parameter file for automation account arm template.
    5. ARM_TMPL_3NIC_2VM_WEBHOOK_3.ps1
        Powershell script to create and run SLB webhook.
    6. ARM_TMPL_3NIC_2VM_SLB_CONFIG_4.ps1
        PowerShell script to configure vThunder instances as a SLB 
    7. ARM_TMPL_3NIC_2VM_SLB_CONFIG_PARAM.json
        Parameter file for SLB
    8. ARM_TMPL_3NIC_2VM_HA_CONFIG_5.ps1
        PowerShell script to enable HA between 2 vThunder instances
    9. ARM_TMPL_3NIC_2VM_HA_CONFIG_PARAM.json
        Parameter file for HA
    10.  ARM_TMPL_3NIC_2VM_GLM_CONFIG_6.ps1
        Powershell script to apply GLM license on both vthunder instances
    11. ARM_TMPL_3NIC_2VM_GLM_CONFIG_PARAM.json
        Parameter file for GLM
    12. ARM_TMPL_3NIC_2VM_SLB_SERVER_RUNBOOK.ps1
        PowerShell script for runbook

**Requirements:**

    1. PowerShell Version 7.2 LTS
    2. Install Azure az module
    https://docs.microsoft.com/en-us/powershell/azure/new-azureps-module-az?view=azps-7.2.0
    3. Set execution policy to Unrestricted
        https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell
    4. Access of a10 GLM account https://glm.a10networks.com/ 

**Execution Step - ARM Template and powershell scripts**

    1. deploy ARM template to create 2 vThunder 3 NIC architecture
        az deployment group create --resource-group <resource-group-name> --template-file ARM_TMPL_3NIC_2VM_1.json --parameters ARM_TMPL_3NIC_2VM_PARAM.json
    2. Run script to create automation account and variables
        .\ARM_TMPL_3NIC_2VM_AUTOMATION_ACCOUNT_2.ps1
    3. Run script to create webhook
        .\ARM_TMPL_3NIC_2VM_WEBHOOK_3.ps1
    4. Run script to configure vThunders as SLB
       .\ARM_TMPL_3NIC_2VM_SLB_CONFIG_4.ps1 -resourceGroup <resource-group-name>
    5. Run script to enable HA between 2 vThunder instances
       .\ARM_TMPL_3NIC_2VM_HA_CONFIG_5.ps1 -resourceGroup <resource-group-name>
    6. Run script to apply GLM license on both vthunder instances
       .\ARM_TMPL_3NIC_2VM_GLM_CONFIG_6.ps1 -resourceGroup <resource-group-name>