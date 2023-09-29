### Server Load Balancer (SLB)
This template configures the Thunder instance as a Server Load Balancer (SLB) to evenly distribute the traffic across the set of predefined servers and requires manual scaling.

**Files**

    1. SLB_CONFIG_PARAM.json this file contains the SLB related default configuration values. 
    2. SLB_CONFIG.ps1 Powershell script to configure SLB on Thunder instances.
    3. HTTP_TEMPLATE.ps1 this script will get executed internally by SLB_CONFIG.ps1, If "templateHTTP" is configured (templateHTTP=1) in SLB_CONFIG_PARAM.json file. 
    4. PERSIST_COOKIE_TEMPLATE.ps1 this script will get executed internally by SLB_CONFIG.ps1, If "templatePersistCookie" is configured (templatePersistCookie=1) in SLB_CONFIG_PARAM.json file. 

**Requirements**

    1. PowerShell Version 7.2 LTS
	   https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2
	    
    2. Set execution policy to Unrestricted (only for windows machine)
        PS C:\Users\TestUser\Templates> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
        
        For more information : see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell

**Execution Steps**

Navigate to the PowerShell template directory which needs to be applied and follow the below steps.

1. Open the SLB_CONFIG_PARAM.json parameter file with a text editor.
2. Configure the parameters as appropriate.
3. Verify if all the configurations in the SLB_CONFIG_PARAM.json parameter file are correct and then save the changes.
4. From the Start menu, open PowerShell and navigate to the folder where you have downloaded the PowerShell template.
5. Run the following command to apply configuration in Thunder:

    ```PS C:\Users\TestUser\Templates>.\SLB_CONFIG.ps1"```

6. To verify the applied configuration, follow the below steps:

  1. SSH into the Thunder device using your username and password.
  2. Once connected, enter the following commands:

     1. `enable`

     2. `show running-config`
