**Files:**

    1. PS_TMPL_3NIC_2VM_HA_1.ps1
        PowerShell template to create 3 NIC 2 vThunder instances.
    2. PS_TMPL_3NIC_2VM_HA_PARAM.json
        Parameter file for ARM and PowerShell template.
    3. PS_TMPL_3NIC_2VM_HA_SLB_CONFIG_2.ps1
        PowerShell script to configure vThunder instances as a SLB 
    4. PS_TMPL_3NIC_2VM_HA_SLB_CONFIG_PARAM.json
        Parameter file for SLB
    5. PS_TMPL_3NIC_2VM_HA_CONFIG_3.ps1
        PowerShell script to enable HA between 2 vThunder instances
    6. PS_TMPL_3NIC_2VM_HA_CONFIG_PARAM.json
        Parameter file for HA

**Requirements:**

    1. PowerShell Version 7.2 LTS
    2. Install Azure az module
    https://docs.microsoft.com/en-us/powershell/azure/new-azureps-module-az?view=azps-7.2.0
    1. Set execution policy to Unrestricted
        https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell

**Execution Step - PowerShell**

    1. Run script to create 2 vThunder 3 NIC architecture
        .\PS_TMPL_3NIC_2VM_HA_1.ps1 -resourceGroup <resource-group-name> -location <location>
    2. Run script to configure vThunders as SLB
        .\PS_TMPL_3NIC_2VM_HA_SLB_CONFIG_2.ps1 -resourceGroup <resource-group-name>
    3. Run script to enable HA between 2 vThunder instances
       .\PS_TMPL_3NIC_2VM_HA_CONFIG_3.ps1 -resourceGroup <resource-group-name>
