### A10 License (GLM)
This template applies GLM license to the Thunder instance for legal compliance, security, all feature access, and support.


**Files**

    1. GLM_CONFIG_PARAM.json This file contains the entitlement token and Thunder ip user name details.
    2. GLM_CONFIG.ps1 Powershell script to configure GLM on Thunder instances. 

**Requirements**

    1. PowerShell Version 7.2 LTS
	   https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2
	    
    2. Set execution policy to Unrestricted (only for windows machine)
        PS C:\Users\TestUser\Templates> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
        
        For more information : see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell
  
	3. Entitlement token of a10 GLM license
	   https://glm.a10networks.com/ 

**Execution Step**

Navigate to the PowerShell template directory which needs to be applied and follow the below steps.

1. Open the GLM_CONFIG_PARAM.json parameter file with a text editor.
2. Configure the parameters as appropriate.
3. Verify if all the configurations in the GLM_CONFIG_PARAM.json parameter file are correct and then save the changes.
4. From the Start menu, open PowerShell and navigate to the folder where you have downloaded the PowerShell template.
5. Run the following command to apply configuration in Thunder:

    ```PS C:\Users\TestUser\Templates>.\GLM_CONFIG.ps1"```

6. To verify the applied configuration, follow the below steps:

  1. SSH into the Thunder device using your username and password.
  2. Once connected, enter the following commands:

     1. `enable`

     2. `show running-config`