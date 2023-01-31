**Files:**

    1. PS_TMPL_3NIC_2VM_HA_GLM_PVTVIP_1.ps1
        PowerShell template to create 3 NIC 2 vThunder instances.
    2. PS_TMPL_3NIC_2VM_HA_GLM_PVTVIP_PARAM.json
        Parameter file for ARM and PowerShell template.
    3. PS_TMPL_3NIC_2VM_HA_GLM_CHANGE_PASSWORD_2.ps1
       Powershell template to change password of vThunders
    4. PS_TMPL_3NIC_2VM_SLB_CONFIG_2.ps1
        PowerShell script to configure vThunder instances as a SLB 
    5. PS_TMPL_3NIC_2VM_SLB_CONFIG_PARAM.json
        Parameter file for SLB
    6. PS_TMPL_3NIC_2VM_HA_CONFIG_3.ps1
        PowerShell script to enable HA between 2 vThunder instances
    7. PS_TMPL_3NIC_2VM_HA_CONFIG_PARAM.json
        Parameter file for HA
    8. PS_TMPL_3NIC_2VM_GLM_CONFIG_4.ps1
        PowerShell script to apply GLM licenses on both vThunders.
    9. PS_TMPL_3NIC_2VM_GLM_CONFIG_PARAM.json
        Parameter file for GLM licenses

**Requirements:**

    1. PowerShell Version 7.2 LTS
	   https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2
	   
    2. Install Azure az module
       https://docs.microsoft.com/en-us/powershell/azure/new-azureps-module-az?view=azps-7.2.0
	
    3. Set execution policy to Unrestricted (only for windows machine)
       https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell
    	
    4. GLM portal access with valid licenses.
       https://glm.a10networks.com/
	  
	5. Azure CLI installation
	   https://azcliprod.blob.core.windows.net/msi/azure-cli-2.24.0.msi
	   
**Execution Step - PowerShell**

      1. Run script to create 2 vThunder 3 NIC architecture
          .\PS_TMPL_3NIC_2VM_HA_GLM_PVTVIP_1.ps1 -resourceGroup <resource-group-name> -storageaccount <storageaccount> -location <location>
      2. Run script to change password of vThunders
          .\PS_TMPL_3NIC_2VM_HA_GLM_CHANGE_PASSWORD_2.ps1
      3. Run script to configure vThunders as SLB
          .\PS_TMPL_3NIC_2VM_SLB_CONFIG_3.ps1 
      4. Run script to enable HA between 2 vThunder instances
         .\PS_TMPL_3NIC_2VM_HA_CONFIG_4.ps1 
      5. Run script to activate vThunder.
          .\PS_TMPL_3NIC_2VM_GLM_CONFIG_5.ps1
