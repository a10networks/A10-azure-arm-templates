<#
.PARAMETER
	1.RUNBOOK_VARIABLES.json
.Description
    Script for Createing automatation account and variables.
#>

# Authenticate with Azure Portal
Connect-AzAccount

# Get config data
$paramData = Get-Content -Raw -Path ARM_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json | ConvertFrom-Json -AsHashtable

if ($null -eq $paramData) {
    Write-Error "ParamData data is missing." -ErrorAction Stop
}

# get variables value from config file
$azureAutoScaleResources = $paramData.azureAutoScaleResources  | ConvertTo-Json
$glmParam = $paramData.glmParam  | ConvertTo-Json
$sslParam = $paramData.sslParam  | ConvertTo-Json
$slbParam = $paramData.slbParam  | ConvertTo-Json -Depth 4
$autoScaleParam = $paramData.autoScaleParam | ConvertTo-Json
$vThunderIP = $paramData.vThunderIP  | ConvertTo-Json
$clientSecret = $paramData.clientSecret
$resourceGroupName = $paramData.azureAutoScaleResources.resourceGroupName
$automationAccountName = $paramData.azureAutoScaleResources.automationAccountName
$location = $paramData.azureAutoScaleResources.location
$vCPUUsage = $paramData.vCPUUsage
$agentPrivateIP = $paramData.agentPrivateIP

# Create automation account
New-AzAutomationAccount -Name $automationAccountName -Location $location -ResourceGroupName $resourceGroupName

#Create runbook variables
New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "azureAutoScaleResources" -Encrypted $False -Value $azureAutoScaleResources -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "glmParam" -Encrypted $True -Value $glmParam -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "sslParam" -Encrypted $True -Value $sslParam -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "slbParam" -Encrypted $False -Value $slbParam -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "autoScaleParam" -Encrypted $False -Value $autoScaleParam -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vThunderIP" -Encrypted $False -Value $vThunderIP -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "clientSecret" -Encrypted $True -Value $clientSecret -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vCPUUsage" -Encrypted $False -Value $vCPUUsage -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "agentPrivateIP" -Encrypted $False -Value $agentPrivateIP -ResourceGroupName $resourceGroupName
