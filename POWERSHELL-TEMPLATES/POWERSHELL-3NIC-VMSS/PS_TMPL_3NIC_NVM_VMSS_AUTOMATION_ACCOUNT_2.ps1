<#
.PARAMETER
	1.RUNBOOK_VARIABLES.json
.Description
    Script for Createing automatation account and variables.
#>

# Authenticate with Azure Portal
Connect-AzAccount

# Get config data
$paramData = Get-Content -Raw -Path PS_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json | ConvertFrom-Json -AsHashtable

if ($null -eq $paramData) {
    Write-Error "ParamData data is missing." -ErrorAction Stop
}

# get variables value from config file
$azureAutoScaleResources = $paramData.azureAutoScaleResources  | ConvertTo-Json
$glmParam = $paramData.glmParam  | ConvertTo-Json
$sslParam = $paramData.sslParam  | ConvertTo-Json
$slbParam = $paramData.slbParam  | ConvertTo-Json -Depth 4
$autoScaleParam = $paramData.autoScaleParam | ConvertTo-Json
$vThunderIP = $paramData.vThunderIP
$clientSecret = $paramData.clientSecret
$resourceGroupName = $paramData.azureAutoScaleResources.resourceGroupName
$automationAccountName = $paramData.azureAutoScaleResources.automationAccountName
$location = $paramData.azureAutoScaleResources.location
$vCPUUsage = $paramData.vCPUUsage
$agentPrivateIP = $paramData.agentPrivateIP
$vThUserName = $paramData.vThUserName
$isPasswordChangesForAll = $paramData.vThNewPassApplyFlag

$vThDefaultPasswordVal = Read-Host "Enter Default Password" -AsSecureString
$vThDefaultPassword = ConvertFrom-SecureString -SecureString $vThDefaultPasswordVal -AsPlainText

$vThNewPasswordVal = Read-Host "Enter New Password" -AsSecureString
$vThCurrentPasswordVal = $vThNewPasswordVal
$vThCurrentPassword = ConvertFrom-SecureString -SecureString $vThCurrentPasswordVal -AsPlainText
$vThNewPassword = ConvertFrom-SecureString -SecureString $vThNewPasswordVal -AsPlainText
$vThPasswordc = Read-Host "Confirm New Password" -AsSecureString
$vThPasswordConfirm = ConvertFrom-SecureString -SecureString $vThPasswordc -AsPlainText 

if ($vThNewPassword -ne $vThPasswordConfirm) {
    Write-Error "New Password doesn't match." -ErrorAction Stop
}
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

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vThUserName" -Encrypted $False -Value $vThUserName -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vThDefaultPassword" -Encrypted $True -Value $vThDefaultPassword -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vThCurrentPassword" -Encrypted $True -Value $vThCurrentPassword -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vThNewPassword" -Encrypted $True -Value $vThNewPassword -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vThNewPassApplyFlag" -Encrypted $False -Value $isPasswordChangesForAll -ResourceGroupName $resourceGroupName