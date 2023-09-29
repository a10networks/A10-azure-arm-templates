### Server Load Balancer (SLB) On Backend AutoScale
Server Load Balancing is a networking method used to distribute incoming network traffic across a group of servers or devices to improve the performance, reliability, and availability of applications or services.
This template configures Thunder instance as a Server Load Balancer (SLB) to automate the scaling process allowing dynamic adjustment of servers based on the workload.


**Files**

    1. CREATE_AUTOMATION_ACCOUNT_PARAM.json This file contains the Azure service app and SLB port list-related default configuration values.
    2. CREATE_AUTOMATION_ACCOUNT_1.ps1 Powershell script to create automation account and automation account variables on Azure cloud.
    3. CHANGE_PASSWORD_2.ps1 Powershell script to configure the new password on Thunder instances.
    4. SLB_CONFIG_ONDEMAND_PARAM.json This file contains the SLB service group and SLB virtual server-related default configuration values. 
    5. SLB_CONFIG_ONDEMAND_3.ps1 Powershell script to configure SLB service group and SLB virtual server on Thunder instances.
    6. SLB_SERVER_RUNBOOK.ps1 Create Powershell runbook in Azure automation account to configure backend server in Thunder SLB.
    7. CREATE_WEBHOOK_4.ps1  Powershell script to create a webhook that will be used to trigger SLB_SERVER_RUNBOOK.ps1 on scale in and scale out of the backend server.


**Requirements**

    1. PowerShell Version 7.2 LTS
	   https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2
	    
    2. Set execution policy to Unrestricted (only for windows machine)
        PS C:\Users\TestUser\Templates> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
        
        For more information : see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell
  
	3. Azure CLI installation
	   https://azcliprod.blob.core.windows.net/msi/azure-cli-2.24.0.msi


**Execution Step**

Navigate to the PowerShell template directory which needs to be applied and follow the below steps.

1. Open the parameter file with a text editor and update the respective information.
2. Configure the parameters as appropriate.
3. Verify if all the configurations in the parameter file are correct and then save the changes.
4. From the Start menu, open PowerShell and navigate to the folder where you have downloaded the PowerShell template.
5. Run the following command to create an Automation Account in Azure group:

    ```PS C:\Users\TestUser\Templates>.\CREATE_AUTOMATION_ACCOUNT_1.ps1"```

6. Run the following command to apply Change Password configuration in Thunder:

    ```PS C:\Users\TestUser\Templates>.\CHANGE_PASSWORD_2.ps1"```

7. Run the following command to apply SLB configuration in Thunder:

    ```PS C:\Users\TestUser\Templates>.\SLB_CONFIG_ONDEMAND_3.ps1"```

8. Run the following command to create an Create Webhook in Azure group:

    ```PS C:\Users\TestUser\Templates>.\CREATE_WEBHOOK_4.ps1"```

9. Verify if all the above-listed resources are created in the Home > Azure services > Resource Groups > <resource_group_name>.

10. To verify the applied configuration, follow the below steps:

  1. SSH into the Thunder device using your username and password.
  2. Once connected, enter the following commands:

     1. `enable`

     2. `show running-config`
