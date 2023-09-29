# Creating and run webhook
<#
.PARAMETER runBookName
    Name of the runBookName
.Description
    Script to create and run slb runbook
#>

Param (
    [Parameter(Mandatory=$True)]
    [String] $runBookName
 )

$absoluteAmFilePath = -join($PSScriptRoot,"\", "CREATE_AUTOMATION_ACCOUNT_PARAM.json")
$resData = Get-Content -Raw -Path $absoluteAmFilePath | ConvertFrom-Json -AsHashtable
Write-Output $resData

if ($null -eq $resData) {
    Write-Error "resData data is missing." -ErrorAction Stop
}

$resourceGroupName = $resData.resourceGroupName
$automationAccountName = $resData.automationAccountName
$webHookName = "slb-webhook"

# Authenticate with Azure Portal
Login-AzAccount

# Create master runbook webhook
$webHookURL = New-AzAutomationWebhook -Name $webHookName -IsEnabled $True -ExpiryTime "10/2/2030" `
 -RunbookName $runBookName  -ResourceGroupName $resourceGroupName `
 -AutomationAccountName $automationAccountName -Force

Write-Output "Save this URL : "
Write-Output $webHookURL.WebhookURI

# Run master runbook
$response = Invoke-WebRequest -Method Post -Uri $webHookURL.WebhookURI -UseBasicParsing
Write-Host $response