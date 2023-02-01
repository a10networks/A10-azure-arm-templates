**Files:**

    1. ARM_TMPL_3NIC_2VM_HA_1.json
        ARM template to create 3 NIC 2 vThunder instances.
    
	2. ARM_TMPL_3NIC_2VM_HA_PARAM.json
        Parameter file for ARM and PowerShell template.
    
	3. ARM_TMPL_3NIC_2VM_HA_CHANGE_PASSWORD_2.ps1
        PowerShell script to change vThunder password 
		
    4. ARM_TMPL_3NIC_2VM_HA_SLB_CONFIG_3.ps1
        PowerShell script to configure vThunder instances as a SLB 
		
    5. ARM_TMPL_3NIC_2VM_HA_SLB_CONFIG_PARAM.json
        Parameter file for SLB
		
    6. ARM_TMPL_3NIC_2VM_HA_CONFIG_4.ps1
        PowerShell script to enable HA between 2 vThunder instances
		
    7. ARM_TMPL_3NIC_2VM_HA_CONFIG_PARAM.json
        Parameter file for HA

**Requirements:**

    1. PowerShell Version 7.2 LTS
	   https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2
	   
    2. Install Azure az module
	   https://docs.microsoft.com/en-us/powershell/azure/new-azureps-module-az?view=azps-7.2.0
	
    3. Set execution policy to Unrestricted (only for windows machine)
        https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell

	4. Azure CLI installation
	   https://azcliprod.blob.core.windows.net/msi/azure-cli-2.24.0.msi 
	   
**Execution Step - PowerShell**

    1. deploy ARM template to create 2 vThunder 3 NIC architecture
        az deployment group create --resource-group <resource-group-name> --template-file ARM_TMPL_3NIC_2VM_HA_1.json --parameters ARM_TMPL_3NIC_2VM_HA_PARAM.json
    
	2. Run script to change vThunders password
        .\ARM_TMPL_3NIC_2VM_HA_CHANGE_PASSWORD_2.ps1
    
	3. Run script to configure vThunders as SLB
        .\ARM_TMPL_3NIC_2VM_HA_SLB_CONFIG_2.ps1 -resourceGroup <resource-group-name>
    
	4. Run script to enable HA between 2 vThunder instances
       .\ARM_TMPL_3NIC_2VM_HA_CONFIG_3.ps1 -resourceGroup <resource-group-name>
