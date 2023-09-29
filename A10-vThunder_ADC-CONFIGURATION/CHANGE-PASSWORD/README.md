### Change Password
After provisioning the vThunder instance, you can change the Thunder instance password at any given time with this script.

**File**

    1. CHANGE_PASSWORD_SETUP.ps1 Powershell script to configure new password on Thunder instances.

**Requirements**

    1. PowerShell Version 7.2 LTS
	   https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2
	    
    2. Set execution policy to Unrestricted (only for windows machine)
        PS C:\Users\TestUser\Templates> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
        
        For more information : see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell

**Execution Step**

Navigate to the PowerShell template directory which needs to be applied and follow the below steps.

1. Run the following command to apply configuration in Thunder:

    ```PS C:\Users\TestUser\Templates>.\CHANGE_PASSWORD_SETUP.ps1"```

2. To verify the applied configuration, follow the below steps:

  1. SSH into the Thunder device using your username and password.
  2. Once connected, enter the following commands:

     1. `enable`

     2. `show running-config`

    