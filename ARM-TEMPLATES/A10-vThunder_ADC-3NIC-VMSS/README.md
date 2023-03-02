**##ARM Templates**

An internal repository for developing Azure ARM templates.

**Files**:

	1. ARM_TMPL_3NIC_NVM_VMSS_1.json
		ARM template to create 3 NIC NVM vThunder.
	2. ARM_TMPL_3NIC_NVM_VMSS_PARAM.json
		Parameter file for ARM ARM_TMPL_3NIC_NVM_VMSS_1.json template.
	3. ARM_TMPL_3NIC_NVM_VMSS_AUTOMATION_ACCOUNT_2.ps1
		PowerShell template to create automation account and automation variables.
	4. ARM_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json
		Parameter file for PowerShell ARM_TMPL_3NIC_NVM_VMSS_AUTOMATION_ACCOUNT_2.ps1 template.
	5. ARM_TMPL_3NIC_NVM_VMSS_WEBHOOK_3.ps1
		PowerShell template to create webhook, update webhook url and run master book.
	6. ARM_TMPL_3NIC_NVM_VMSS_FUNCTION_APP_4.ps1
		PowerShell template to create Azure function App.
	7. ARM_TMPL_3NIC_NVM_VMSS_FUNCTION_APP_PARAM.json
		Parameter file for PowerShell ARM_TMPL_3NIC_NVM_VMSS_FUNCTION_APP_4.ps1 template.
	8. ARM_TMPL_3NIC_NVM_VMSS_LOG_AGENT_VM_5.ps1
		PowerShell template to configure fluentbit and telegraf agent in Azure agent VM.
	9. ARM_TMPL_3NIC_NVM_VMSS_LOG_AGENT_SHELL_SCRIPT.sh
		Shell script configuration of fluentbit and telegraf agent. 
	10. ARM_TMPL_3NIC_NVM_VMSS_GLM_REVOKE_RUNBOOK.ps1
		 PowerShell template to create revoke glm license runbook.
	11. ARM_TMPL_3NIC_NVM_VMSS_GLM_RUNBOOK.ps1
		PowerShell template to create glm config runbook.
	12. ARM_TMPL_3NIC_NVM_VMSS_MASTER_RUNBOOK.ps1
		 PowerShell template to create master runbook.
	13. ARM_TMPL_3NIC_NVM_VMSS_SLB_RUNBOOK.ps1
		 PowerShell template to create slb config runbook.
	14. ARM_TMPL_3NIC_NVM_VMSS_SSL_RUNBOOK.ps1
		 PowerShell template to create ssl config runbook.
	15. ARM_TMPL_3NIC_NVM_VMSS_ACOS_EVENT_CONFIG_RUNBOOK.ps1
		PowerShell template to create acos event config runbook.

**Requirements**:

	1. Azure account and valid subscription.

	2. Azure CLI installation
	   https://azcliprod.blob.core.windows.net/msi/azure-cli-2.24.0.msi
	   
	3. PowerShell Version 7.2 LTS
	   https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2
	   
	4. Install Azure az module
	   https://www.powershellgallery.com/packages/Az/8.2.0
	   
	5. Set execution policy to Unrestricted (only for windows machine)
	   https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2#managing-the-execution-policy-with-powershell

	6. GLM portal access with valid licenses.
	   https://glm.a10networks.com/
	   
	7. Document editor Notepad++ or Notepad or Any.
    
**Commands**:
 
	1.PowerShell Sample execute command
		.\<powershell-script-name>

	2.ARM Sample execute command
		az deployment group create --resource-group <resource-group-name> --template-file tmpl_file.json --parameters param_file.json

**Execution Step - PowerShell**:

	1. Create 3 NIC NVM vThunder, storage account, LB resources.
	   az deployment group create --resource-group <resource-group-name> --template-file ARM_TMPL_3NIC_NVM_VMSS_1.json --parameters ARM_TMPL_3NIC_NVM_VMSS_PARAM.json
	
	2. Create automation account and automation variables.
		.\ARM_TMPL_3NIC_NVM_VMSS_AUTOMATION_ACCOUNT_2.ps1
	
	3. Create webhook, update webhook url and run master book.
		.\ARM_TMPL_3NIC_NVM_VMSS_WEBHOOK_3.ps1
	
	4. Create Azure function App.
		.\ARM_TMPL_3NIC_NVM_VMSS_FUNCTION_APP_4.ps1
	
	5. Configure fluentbit and telegraf agent.
	   .\ARM_TMPL_3NIC_NVM_VMSS_LOG_AGENT_VM_5.ps1