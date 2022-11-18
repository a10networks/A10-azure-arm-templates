**##PowerShell Scripts**

Requirements:

     1. PowerShell version 7.2 LTS

     2. Install Azure az module
        https://docs.microsoft.com/en-us/powershell/azure/new-azureps-module-az?view=azps-7.2.0
     
     3. Set execution policy to Unrestricted
        https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell

Steps: 

    1. Execute script using command
        ./<powershell-script-name>

**##PS_TMPL_2NIC_1VM_SLB_CONFIG_2.ps1**

    PowerShell script to configure vThunder as SLB.
    Steps:
        1. Execute ARM template or powershell template first to create infrastructure.
        2. Execute script using command
            ./PS_TMPL_2NIC_1VM_SLB_CONFIG_2.ps1 -resourceGroupName <resource-group-name>
