# Creating webhook and updating to automation varibales
<#
.Description
    Script to create webhook, update automation account and run master runbook
#>

$resData = Get-Content -Raw -Path PS_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json | ConvertFrom-Json -AsHashtable
Write-Output $resData

if ($null -eq $resData) {
    Write-Error "resData data is missing." -ErrorAction Stop
}

$resourceGroupName = $resData.azureAutoScaleResources.resourceGroupName
$automationAccountName = $resData.azureAutoScaleResources.automationAccountName
$webHookName = "master-webhook"

# Authenticate with Azure Portal
Login-AzAccount

# Get automation variable values
$azureAutoScaleResources = Get-AzAutomationVariable -Name "azureAutoScaleResources" -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName
$azureAutoScaleResources = $azureAutoScaleResources.Value | ConvertFrom-Json -AsHashtable
$storageAccountName = $azureAutoScaleResources.storageAccountName
$sslParam = $resData.sslParam
$containerName = $sslParam.containerName
$filePath = $sslParam.path
$blobName = -join($sslParam.file, ".", $sslParam.certificationType)

# Get storage account context
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$context = $storageAccount.Context

# upload a ssl file to ssl container
$blobSSL = @{
  File             = $filePath
  Container        = $containerName
  Blob             = $blobName
  Context          = $context
  StandardBlobTier = 'Hot'
}
Set-AzStorageBlobContent @blobSSL

# Create master runbook webhook
$webHookURL = New-AzAutomationWebhook -Name $webHookName -IsEnabled $True -ExpiryTime "10/2/2030" `
 -RunbookName "Master-Runbook"  -ResourceGroupName $resourceGroupName `
 -AutomationAccountName $automationAccountName -Force

Write-Host $webHookURL.WebhookURI

# update webhook url in variable
$azureAutoScaleResources.masterWebhookUrl = $webHookURL.WebhookURI
$azureAutoScaleResources = $azureAutoScaleResources | ConvertTo-Json
$newValue = "$azureAutoScaleResources"
Write-Host $newValue

# Update automation variable
Set-AzAutomationVariable -Name "azureAutoScaleResources" -Value $newValue -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Encrypted $False

# Run master runbook
$body = @{"operation"="Scale Out"
  "context"=@{"resourceName"=$resData.azureAutoScaleResources.vThunderScaleSetName}}
$body = $body | ConvertTo-Json
$response = Invoke-WebRequest -Method Post -Uri $webHookURL.WebhookURI -UseBasicParsing -Body $body
Write-Host $response