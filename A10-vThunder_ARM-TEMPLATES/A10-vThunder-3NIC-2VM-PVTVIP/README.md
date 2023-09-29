### ARM 3NIC 2VM PVTVIP Template
This template deploys 3 network interfaces with 2 virtual machines, allowing users to choose different or the same availability zone as per their selection. 


**Files**

    1. ARM_TMPL_3NIC_2VM_PVTVIP.json ARM template to create resources on Azure Cloud. The template contains default values that users can update as per their requirements.
    2. ARM_TMPL_3NIC_2VM_PVTVIP_PARAM.json file contains default configuration values for 3NIC and 2VM resources. This file is used in CLI deployment, and users can update it as needed.

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
	   

**Execution Step**

**Deploy Thunder instance using an ARM template with Azure console**

Navigate to the ARM template directory which needs to be applied and follow the below steps.

1. From Azure Portal > Azure services, click Deploy a custom template.
2. Under Custom deployment window > Select a template tab, click Build your own template in the editor.
3. From the Edit template window, click Load file to upload the ARM_TMPL_3NIC_2VM_PVTVIP.json template from your local machine or paste the content of the file into the editor.
4. Click Save.
5. Select an existing or create a new Resource group under which you want to deploy the custom template resources.
6. Update the default values and provide the values in the empty fields as appropriate in the Instance details section
7. Click Review+create.
8. Click Create.
9. Verify if all the above-listed resources are created in the Home > Azure services > Resource Groups > <resource_group_name>.


**Deploy Thunder instance using an ARM template with PowerShell CLI**

Navigate to the ARM template directory which needs to be applied and follow the below steps.

1. Open the ARM_TMPL_3NIC_2VM_PVTVIP_PARAM.json parameters file with a text editor.
2. Configure the parameters as appropriate.
3. Verify if all the configurations in the ARM_TMPL_3NIC_2VM_PVTVIP_PARAM.json file are correct and then save the changes.
4. From the Start menu, open PowerShell and navigate to the folder where you have downloaded the ARM template.
5. Run the following command to create an Azure resource group:

    ```PS C:\Users\TestUser\Templates>az group create --name <resource_group_name> --location "<location_name>"```

6. Run the following command to create an Azure deployment group.

    ```PS C:\Users\TestUser\Templates>az deployment group create -g <resource_group_name> --template-file ARM_TMPL_3NIC_2VM_PVTVIP.json --parameters ARM_TMPL_3NIC_2VM_PVTVIP_PARAM.json```

7. Verify if all the above-listed resources are created in the Home > Azure services > Resource Groups > <resource_group_name>.
