<#
.PARAMETER
	1.RUNBOOK_VARIABLES.json
.Description
    Script for Createing automatation account and variables.
#>

# Authenticate with Azure Portal
Connect-AzAccount

# Get config data
$paramData = Get-Content -Raw -Path PS_TMPL_3NIC_2VM_AUTOMATION_ACCOUNT_PARAM.json | ConvertFrom-Json -AsHashtable

if ($null -eq $paramData) {
    Write-Error "ParamData data is missing." -ErrorAction Stop
}

# get variables value from config file
$automationAccountName = $paramData.automationAccountName
$location = $paramData.location
$clientSecret = $paramData.clientSecret
$appId = $paramData.appId
$tenantId = $paramData.tenantId
$resourceGroupName = $paramData.resourceGroupName
$vmssName = $paramData.vmssName
$mgmtInterface1 = $paramData.mgmtInterface1
$mgmtInterface2 = $paramData.mgmtInterface2
$slbParam = $paramData.portList  | ConvertTo-Json -Depth 3
$vThUsername = $paramData.vThUsername


# Create automation account
New-AzAutomationAccount -Name $automationAccountName -Location $location -ResourceGroupName $resourceGroupName

#Create runbook variables
New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "clientSecret" -Encrypted $True -Value $clientSecret -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "appId" -Encrypted $False -Value $appId -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "tenantId" -Encrypted $False -Value $tenantId -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "resourceGroupName" -Encrypted $False -Value $resourceGroupName -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vmssName" -Encrypted $False -Value $vmssName -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "mgmtInterface1" -Encrypted $False -Value $mgmtInterface1 -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "mgmtInterface2" -Encrypted $False -Value $mgmtInterface2 -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "portList" -Encrypted $False -Value $slbParam -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vThUsername" -Encrypted $False -Value $vThUsername -ResourceGroupName $resourceGroupName
