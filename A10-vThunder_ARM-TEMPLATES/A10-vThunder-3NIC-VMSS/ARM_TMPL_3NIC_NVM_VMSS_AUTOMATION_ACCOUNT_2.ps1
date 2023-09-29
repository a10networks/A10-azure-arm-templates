<#
.PARAMETER
	1.RUNBOOK_VARIABLES.json
.Description
    Script for Createing automatation account and variables.
#>

# Authenticate with Azure Portal
Connect-AzAccount

# Get config data
$absoluteFilePath = -join($PSScriptRoot,"\", "ARM_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json")
$paramData = Get-Content -Raw -Path $absoluteFilePath | ConvertFrom-Json -AsHashtable

if ($null -eq $paramData) {
    Write-Error "ParamData data is missing." -ErrorAction Stop
}

# get variables value from config file
$azureAutoScaleResources = $paramData.azureAutoScaleResources  | ConvertTo-Json
$glmParam = $paramData.glmParam  | ConvertTo-Json
$sslParam = $paramData.sslParam  | ConvertTo-Json
$slbParam = $paramData.slbParam  | ConvertTo-Json -Depth 5
$vThunderIP = $paramData.vThunderIP
$clientSecret = $paramData.clientSecret
$resourceGroupName = $paramData.azureAutoScaleResources.resourceGroupName
$automationAccountName = $paramData.azureAutoScaleResources.automationAccountName
$location = $paramData.azureAutoScaleResources.location
$vThUsername = $paramData.vThUserName
$isPasswordChangesForAll = $paramData.vThNewPassApplyFlag

$vThDefaultPasswordVal = Read-Host "Enter Default Password" -AsSecureString
$vThDefaultPassword = ConvertFrom-SecureString -SecureString $vThDefaultPasswordVal -AsPlainText
Write-Host "`n--------------------------------------------------------------------------------------------------------------------"
Write-Host "Primary conditions for password validation, user should provide the new password according to the given combination: `n`nMinimum length of 9 characters`nMinimum lowercase character should be 1`nMinimum uppercase character should be 1`nMinimum number should be 1`nMinimum special character should be 1`nShould not include repeated characters`nShould not include more than 3 keyboard consecutive characters."
Write-Host "--------------------------------------------------------------------------------------------------------------------`n"
$vThNewPasswordVal = Read-Host "Enter New Password" -AsSecureString
$vThCurrentPasswordVal = $vThNewPasswordVal
$vThCurrentPassword = ConvertFrom-SecureString -SecureString $vThCurrentPasswordVal -AsPlainText
$vThNewPassword = ConvertFrom-SecureString -SecureString $vThNewPasswordVal -AsPlainText
$vThPasswordc = Read-Host "Confirm New Password" -AsSecureString
$vThPasswordConfirm = ConvertFrom-SecureString -SecureString $vThPasswordc -AsPlainText

if ($vThNewPassword -ne $vThPasswordConfirm) {
    Write-Error "New Password doesn't match." -ErrorAction Stop
}

$logAnalyticsWorkspaceName = $paramData.azureAutoScaleResources.logAnalyticsWorkspaceName

$appInsights_obj = Get-AzApplicationInsights -ResourceGroupName $resourceGroupName -Name $paramData.azureAutoScaleResources.appInsightsName
$appInsightsId = $appInsights_obj.Id

$workspace_obj = Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName -Name $logAnalyticsWorkspaceName
$workspaceId = $workspace_obj.CustomerId

$shared_key_obj = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $resourceGroupName -Name $logAnalyticsWorkspaceName
$sharedKey = $shared_key_obj.PrimarySharedKey

#Create runbook variables
New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "azureAutoScaleResources" -Encrypted $False -Value $azureAutoScaleResources -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "glmParam" -Encrypted $True -Value $glmParam -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "sslParam" -Encrypted $True -Value $sslParam -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "slbParam" -Encrypted $False -Value $slbParam -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vThunderIP" -Encrypted $False -Value $vThunderIP -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "clientSecret" -Encrypted $True -Value $clientSecret -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "location" -Encrypted $False -Value $location -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vThUserName" -Encrypted $False -Value $vThUserName -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vThDefaultPassword" -Encrypted $True -Value $vThDefaultPassword -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vThCurrentPassword" -Encrypted $True -Value $vThCurrentPassword -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vThNewPassword" -Encrypted $True -Value $vThNewPassword -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "vThNewPassApplyFlag" -Encrypted $False -Value $isPasswordChangesForAll -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "workspaceId" -Encrypted $False -Value $workspaceId -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "sharedKey" -Encrypted $True -Value $sharedKey -ResourceGroupName $resourceGroupName

New-AzAutomationVariable -AutomationAccountName $automationAccountName -Name "appInsightsId" -Encrypted $False -Value $appInsightsId -ResourceGroupName $resourceGroupName
