### ARM 3NIC VMSS Template
This template deploys 3 network interfaces with virtual machines scale set. 


**Files**

    1. ARM_TMPL_3NIC_NVM_VMSS_1.json ARM template to create resources on Azure Cloud. The template contains default values that users can update as per their requirements.
    2. ARM_TMPL_3NIC_NVM_VMSS_PARAM.json file contains default configuration values for 3NIC and VMSS resources. This file is used in CLI deployment, and users can update it as needed.
	3. ARM_TMPL_3NIC_NVM_VMSS_AUTOMATION_ACCOUNT_2.ps1 PowerShell template to create automation account and automation variables.
	4. ARM_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json parameter file for automation account, automation account vairables, Azure service app.
	5. ARM_TMPL_3NIC_NVM_VMSS_WEBHOOK_3.ps1 PowerShell script to create webhook, update webhook url and run master book.


**Requirements**

    1. PowerShell Version 7.2 LTS
	   https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2
	    
    2. Set execution policy to Unrestricted (only for windows machine)
        PS C:\Users\TestUser\Templates> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
        
        For more information : see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell

    3. Azure CLI installation
	   https://azcliprod.blob.core.windows.net/msi/azure-cli-2.24.0.msi

    4. Install Azure az module
	   https://www.powershellgallery.com/packages/Az/8.2.0

	5. Access details of A10 Networks GLM Portal
	   https://glm.a10networks.com/ 
    

**Execution Steps**

**Deploy Thunder instance using an ARM template with Azure console**

Navigate to the ARM template directory which needs to be applied and follow the below steps.

1. From Azure Portal > Azure services, click Deploy a custom template.
2. Under Custom deployment window > Select a template tab, click Build your own template in the editor.
3. From the Edit template window, click Load file to upload the ARM_TMPL_3NIC_NVM_VMSS_1.json template from your local machine or paste the content of the file into the editor.
4. Click Save.
5. Select an existing or create a new Resource group under which you want to deploy the custom template resources.
6. Update the default values and provide the values in the empty fields as appropriate in the Instance details section
7. Click Review+create.
8. Click Create.
9. Verify if all the above-listed resources are created in the Home > Azure services > Resource Groups > <resource_group_name>.


**Deploy Thunder instance using an ARM template with PowerShell CLI**

Navigate to the ARM template directory which needs to be applied and follow the below steps.

1. Open the ARM_TMPL_3NIC_NVM_VMSS_PARAM.json parameters file with a text editor.
2. Configure the parameters as appropriate.
3. Verify if all the configurations in the ARM_TMPL_3NIC_NVM_VMSS_PARAM.json file are correct and then save the changes.
4. From the Start menu, open PowerShell and navigate to the folder where you have downloaded the ARM template.
5. Run the following command to create an Azure resource group:

    ```PS C:\Users\TestUser\Templates>az group create --name <resource_group_name> --location "<location_name>"```

6. Run the following command to create an Azure deployment group.

    ```PS C:\Users\TestUser\Templates>az deployment group create -g <resource_group_name> --template-file ARM_TMPL_3NIC_NVM_VMSS_1.json --parameters ARM_TMPL_3NIC_NVM_VMSS_PARAM.json```

7. Verify if all the above-listed resources are created in the Home > Azure services > Resource Groups > <resource_group_name>.

**Deploy Azure automation account and automation variables with PowerShell CLI**

Navigate to the ARM template directory which needs to be applied and follow the below steps.

1. Open the ARM_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json parameters file with a text editor.
2. Configure the parameters as appropriate.
3. Verify if all the configurations in the ARM_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json file are correct and then save the changes.
4. From the Start menu, open PowerShell and navigate to the folder where you have downloaded the ARM template.
5. Run the following command to create an Azure resources.

    ```PS C:\Users\TestUser\Templates>.\ARM_TMPL_3NIC_NVM_VMSS_AUTOMATION_ACCOUNT_2.ps1"```

6. Verify if all the above-listed resources are created in the Home > Azure services > Resource Groups > <resource_group_name>.

**Create webhook, upload ssl file, update webhook url and run master book with PowerShell CLI**

Navigate to the ARM template directory which needs to be applied and follow the below steps.

1. Open the ARM_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json parameters file with a text editor.
2. Configure the parameters as appropriate.
3. Verify if all the configurations in the ARM_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json file are correct and then save the changes.
4. From the Start menu, open PowerShell and navigate to the folder where you have downloaded the ARM template.
5. Run the following command to create an Azure resources.

    ```PS C:\Users\TestUser\Templates>.\ARM_TMPL_3NIC_NVM_VMSS_WEBHOOK_3.ps1"```

6. Verify if all the above-listed resources are created in the Home > Azure services > Resource Groups > <resource_group_name>.
