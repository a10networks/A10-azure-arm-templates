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

# Get config data from PS_TMPL_3NIC_NVM_VMSS_FUNCTION_APP_PARAM
$functionParamData = Get-Content -Raw -Path PS_TMPL_3NIC_NVM_VMSS_FUNCTION_APP_PARAM.json | ConvertFrom-Json -AsHashtable

if ($null -eq $functionParamData) {
    Write-Error "ParamData data is missing." -ErrorAction Stop
}

# Get config data from PS_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json
$azureParamData = Get-Content -Raw -Path PS_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json | ConvertFrom-Json -AsHashtable

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

# Cretae azure application Insights
#New-AzApplicationInsights -ResourceGroupName $resourceGroupName -Name $applicationInsightsName -location $location

# Get azure application Insights object
$applicationInsights = Get-AzApplicationInsights -Name $applicationInsightsName -ResourceGroupName $resourceGroupName

# Cretae azure function app
New-AzFunctionApp -Name $functionAppName -ResourceGroupName $resourceGroupName -Location $location -StorageAccount $storageAccountName `
 -Runtime "Python" -RuntimeVersion "3.9" -OSType "Linux" -ApplicationInsightsName $applicationInsightsName `
 -ApplicationInsightsKey $applicationInsights.InstrumentationKey

# upload getmatrex functions to azure function app
Publish-AzWebapp -ResourceGroupName $resourceGroupName -Name $functionAppName -ArchivePath $filePath

# app setting
$appSetting = @{"AZURE_CLIENT_ID"= $azureClientID; "AZURE_CLIENT_SECRET" = $azureClientIDSecret;
                 "AZURE_TENANT_ID"= $appTenantID; "AutomationAccName" = $automationAccName; 
                 "ResourceGroupName" = $resourceGroupName; "SubscriptionId" = $subscriptionId}

# configure app setting
Update-AzFunctionAppSetting -Name $functionAppName -ResourceGroupName $resourceGroupName `
 -AppSetting $appSetting