**##PowerShell Scripts**

Requirements:

    1. PowerShell version 7.2  LTS
	   https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2

    2. Install Azure az module
       https://docs.microsoft.com/en-us/powershell/azure/new-azureps-module-az?view=azps-7.2.0
     
    3. Set execution policy to Unrestricted (only for windows machine)
       https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell
	 
	4. Azure CLI installation
	   https://azcliprod.blob.core.windows.net/msi/azure-cli-2.24.0.msi
	   
Steps: 

    1. Execute script using command
        az deployment group create -g resourceGroupName --template-file .\ARM_TMPL_2NIC_1VM_GLM_1.json --parameters .\ARM_TMPL_2NIC_1VM_GLM_PARAM.json

**##ARM_TMPL_2NIC_1VM_GLM_CHANGE_PASSWORD_2.ps1**

    PowerShell script to chagne vThunder password.
    Steps:
        1. Execute script using command
            .\ARM_TMPL_2NIC_1VM_GLM_CHANGE_PASSWORD_2.ps1

**##ARM_TMPL_2NIC_1VM_GLM_SLB_CONFIG_3.ps1**

    PowerShell script to configure vThunder as SLB.
    Steps:
        1. Execute script using command
            .\ARM_TMPL_2NIC_1VM_GLM_SLB_CONFIG_3.ps1

**##ARM_TMPL_2NIC_1VM_GLM_CONFIG_4.ps1**

    Powershell script to apply Glm license on created 2nic 1vthunder.
    Steps:
        1. Execute script using command
            .\ARM_TMPL_2NIC_1VM_GLM_CONFIG_3.ps1 -resourceGroupName <resource-group-name>
