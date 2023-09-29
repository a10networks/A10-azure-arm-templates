### High Availability (HA)
This template applies high availability configuration to the vThunder instances. It automatically synchronizes Thunder configurations between the active and standby Thunder instances. 
In the event of a failover, it designates the other Thunder instance as active to ensure uninterrupted traffic routing. For this functionality, it is essential for both Thunder instances to have identical resources and configurations.


**Files**

    1. HA_CONFIG_PARAM.json This file contains the HA related default configuration values.
    2. HA_CONFIG.ps1 Powershell script to configure HA on Thunder.


**Requirements**

    1. PowerShell Version 7.2 LTS
	   https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2
	    
    2. Set execution policy to Unrestricted (only for windows machine)
        PS C:\Users\TestUser\Templates> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
        
        For more information : see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell


**Execution Step**

Navigate to the PowerShell template directory which needs to be applied and follow the below steps.

1. Open the HA_CONFIG_PARAM.json parameter file with a text editor.
2. Configure the parameters as appropriate.
3. Verify if all the configurations in the HA_CONFIG_PARAM.json parameter file are correct and then save the changes.
4. From the Start menu, open PowerShell and navigate to the folder where you have downloaded the PowerShell template.
5. Run the following command to apply configuration in Thunder:

    ```PS C:\Users\TestUser\Templates>.\HA_CONFIG.ps1"```

6. To verify the applied configuration, follow the below steps:

  1. SSH into the Thunder device using your username and password.
  2. Once connected, enter the following commands:

     1. `enable`

     2. `show running-config`
     
