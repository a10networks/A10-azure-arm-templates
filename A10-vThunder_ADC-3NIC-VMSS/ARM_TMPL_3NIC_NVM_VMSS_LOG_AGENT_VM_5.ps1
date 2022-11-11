<#
.Description
    Script to configure a log agent in vm.
#>

$resData = Get-Content -Raw -Path ARM_TMPL_3NIC_NVM_VMSS_RUNBOOK_VARIABLES.json | ConvertFrom-Json -AsHashtable
Write-Output $resData

if ($null -eq $resData) {
    Write-Error "resData data is missing." -ErrorAction Stop
}

$resourceGroupName = $resData.azureAutoScaleResources.resourceGroupName
$location = $resData.azureAutoScaleResources.location

$workingDir = Get-Location
Compress-Archive -Path "..\..\plugins" -DestinationPath "plugins.zip"
$absoluteFilePath = -join($workingDir,"\", "ARM_TMPL_3NIC_NVM_VMSS_LOG_AGENT_SHELL_SCRIPT.sh")
$zipAbsoluteFilePath = -join($workingDir,"\", "plugins.zip")

# Authenticate with Azure Portal
Connect-AzAccount

# Get resource config from variables
$paramData = Get-Content -Raw -Path ARM_TMPL_3NIC_NVM_VMSS_PARAM.json | ConvertFrom-Json -AsHashtable
Write-Output $paramData

# Get paramaters
$blobName = "ARM_TMPL_3NIC_NVM_VMSS_LOG_AGENT_SHELL_SCRIPT.sh"
$zipBlobName = "plugins.zip"
$storageAccountName = $paramData.parameters.storageAccountName.value
$containerName = $paramData.parameters.logAgentContainerName.value
$vmName = $paramData.parameters.vmName.value

# Get storage account context
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$context = $storageAccount.Context

# upload a shell script file to shellScript container and get flie url
$blobShellScript = @{
  File             = $absoluteFilePath
  Container        = $containerName
  Blob             = $blobName
  Context          = $context
  StandardBlobTier = 'Hot'
}
$setObj = Set-AzStorageBlobContent @blobShellScript
$url = $setObj.ICloudBlob.Uri.AbsoluteUri

# upload a zip file to shellScript container and get flie url
$zipBlob = @{
  File             = $zipAbsoluteFilePath
  Container        = $containerName
  Blob             = $zipBlobName
  Context          = $context
  StandardBlobTier = 'Hot'
}
$zipObj = Set-AzStorageBlobContent @zipBlob
$zipURL = $zipObj.ICloudBlob.Uri.AbsoluteUri

# shell command
$command = -join("sudo ./",$blobName," > output.txt &")

# zip cp shell command
$cpCommand = -join("sudo cp ",$zipBlobName," /usr/local/ &")

# Retrieve storage account key
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName).Value[0]

# set up extensions config
$extensions = Get-AzVMExtensionImage -Location $location -PublisherName "Microsoft.Azure.Extensions" -Type "CustomScript"
$extension = $extensions | Sort-Object -Property Version -Descending | Select-Object -First 1
$extensionVersion = $extension.Version[0..2] -join ""
$scriptSettings = @{"fileUris" = @("$url")};
$protectedSettings = @{"storageAccountName" = $storageAccountName; "storageAccountKey" = $storageAccountKey; "commandToExecute" = $command};

$zipScriptSettings = @{"fileUris" = @("$zipURL")};
$zipProtectedSettings = @{"storageAccountName" = $storageAccountName; "storageAccountKey" = $storageAccountKey; "commandToExecute" = $cpCommand};

# run extension script to copy zip file
Set-AzVMExtension -ResourceGroupName $resourceGroupName -Location $location -VMName $vmName -Name $extension.Type -Publisher $extension.PublisherName -ExtensionType $extension.Type -TypeHandlerVersion $extensionVersion -Settings $zipScriptSettings -ProtectedSettings $zipProtectedSettings

# run extension script
Set-AzVMExtension -ResourceGroupName $resourceGroupName -Location $location -VMName $vmName -Name $extension.Type -Publisher $extension.PublisherName -ExtensionType $extension.Type -TypeHandlerVersion $extensionVersion -Settings $scriptSettings -ProtectedSettings $protectedSettings