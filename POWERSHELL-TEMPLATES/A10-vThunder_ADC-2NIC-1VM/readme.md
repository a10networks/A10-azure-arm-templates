**##PowerShell Scripts**

Requirements:

     1. PowerShell version 7.2 LTS
	    https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2
		
     2. Install Azure az module
        https://www.powershellgallery.com/packages/Az/8.3.0
     
     3. Set execution policy to Unrestricted (only for windows machine)
        https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell
		
	 4. Azure CLI installation
		https://azcliprod.blob.core.windows.net/msi/azure-cli-2.24.0.msi
		
Steps: 

    1. Execute script using command
        ./<powershell-script-name>

**##PS_TMPL_2NIC_1VM_CHANGE_PASSWORD_2.ps1**

    PowerShell script to change password for vThunder.
    Steps:
        1. Execute ARM template or powershell template first to create infrastructure.
        2. Execute script using command
            ./PS_TMPL_2NIC_1VM_CHANGE_PASSWORD_2.ps1

**##PS_TMPL_2NIC_1VM_SLB_CONFIG_3.ps1**

    PowerShell script to configure vThunder as SLB.
    Steps:
        1. Execute ARM template or powershell template first to create infrastructure.
        2. Execute script using command
            ./PS_TMPL_2NIC_1VM_SLB_CONFIG_3.ps1 