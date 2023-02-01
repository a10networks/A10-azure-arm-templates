<#
.PARAMETER function App Name, application Insights Name
    function app param file
.EXAMPLE
    To run script execute .\<name-of-script>
.Description
    Script to create azure function, application insights
#>

# Authenticate with Azure Portal
Login-AzAccount

# Get config data from ARM_TMPL_3NIC_NVM_VMSS_FUNCTION_APP_PARAM
$functionParamData = Get-Content -Raw -Path ARM_TMPL_3NIC_NVM_VMSS_FUNCTION_APP_PARAM.json | ConvertFrom-Json -AsHashtable

if ($null -eq $functionParamData) {
    Write-Error "ParamData data is missing." -ErrorAction Stop
}

# Get config data from ARM_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json
$azureParamData = Get-Content -Raw -Path ARM_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json | ConvertFrom-Json -AsHashtable

if ($null -eq $azureParamData) {
    Write-Error "azureParamData data is missing." -ErrorAction Stop
}

# get variables value from config file
$azureClientIDSecret = $azureParamData.clientSecret
$azureParamData = $azureParamData.azureAutoScaleResources
$resourceGroupName = $azureParamData.resourceGroupName
$storageAccountName = $azureParamData.storageAccountName
$azureClientID = $azureParamData.appId
$appTenantID = $azureParamData.tenantId
$automationAccName = $azureParamData.automationAccountName
$location = $azureParamData.location

$functionAppName = $functionParamData.functionAppName
$applicationInsightsName = $functionParamData.applicationInsightsName
$subscriptionId = $functionParamData.subscriptionId
$filePath = $functionParamData.filePath
$vThUserName = $functionParamData.vThUserName

# Get updated current password from user and encrypt it
$output = Python .\utils\Encrypt_Password.py
if ($output -eq 401) {
    Write-Error 'Current and Confirm password does not match.' -ErrorAction Stop
}

$output = $output.Split(' ')
$encryptionKey = $output[0]
$encryptedPassword = $output[1]

# Get azure application Insights object
$applicationInsights = Get-AzApplicationInsights -Name $applicationInsightsName -ResourceGroupName $resourceGroupName

# Cretae azure function app
New-AzFunctionApp -Name $functionAppName -ResourceGroupName $resourceGroupName -Location $location -StorageAccount $storageAccountName `
 -Runtime "Python" -RuntimeVersion "3.9" -OSType "Linux" -ApplicationInsightsName $applicationInsightsName `
 -ApplicationInsightsKey $applicationInsights.InstrumentationKey

# upload getmatrex functions to azure function app
$status = Publish-AzWebapp -ResourceGroupName $resourceGroupName -Name $functionAppName -ArchivePath $filePath
Write-Output $status

# app setting
$appSetting = @{"AZURE_CLIENT_ID"= $azureClientID; "AZURE_CLIENT_SECRET" = $azureClientIDSecret;
                 "AZURE_TENANT_ID"= $appTenantID; "AutomationAccName" = $automationAccName; 
                 "ResourceGroupName" = $resourceGroupName; "SubscriptionId" = $subscriptionId;
                "vThUserName" = $vThUserName; "vThCurrentPassword" = $encryptedPassword;
                 "vThPasswordEncryptionKey" = $encryptionKey; "vThDefaultPassword" = "a10"}

# configure app setting
Update-AzFunctionAppSetting -Name $functionAppName -ResourceGroupName $resourceGroupName `
 -AppSetting $appSetting