### ARM 3NIC 3VM Template
This template deploys 3 network interfaces with 3 virtual machines. 


**Files**

    1. ARM_TMPL_3NIC_3VM.json ARM template to create resources on Azure Cloud. The template contains default values that users can update as per their requirements.

**Requirements**

	1. Azure account and valid subscription.

**Execution Step**

**Deploy Thunder instance using an ARM template with Azure console**

Navigate to the ARM template directory which needs to be applied and follow the below steps.

1. From Azure Portal > Azure services, click Deploy a custom template.
2. Under Custom deployment window > Select a template tab, click Build your own template in the editor.
3. From the Edit template window, click Load file to upload the ARM_TMPL_3NIC_3VM.json template from your local machine or paste the content of the file into the editor.
4. Click Save.
5. Select an existing or create a new Resource group under which you want to deploy the custom template resources.
6. Update the default values and provide the values in the empty fields as appropriate in the Instance details section
7. Click Review+create.
8. Click Create.
9. Verify if all the above-listed resources are created in the Home > Azure services > Resource Groups > <resource_group_name>.

    
