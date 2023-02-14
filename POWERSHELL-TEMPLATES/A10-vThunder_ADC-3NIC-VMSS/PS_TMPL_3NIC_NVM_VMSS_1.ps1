#Deploying azure VMSS from marketplace
<#
.PARAMETER resource group, storage account, location
    Name of resource group, location
.EXAMPLE
    To run script execute .\<name-of-script> <resource-group-name> <storage-account-name> <location-name>
.Description
    Script to create vmss vthunder instance
#>

Param (
     [Parameter(Mandatory=$True)]
     [String] $resourceGroupName,
     [Parameter(Mandatory=$True)]
     [String] $location
 )

# Get config data from param file
$paramData = Get-Content -Raw -Path PS_TMPL_3NIC_NVM_VMSS_PARAM.json | ConvertFrom-Json

# Authenticate with Azure Portal
Connect-AzAccount

# Get variables value
$vmssName =  $paramData.parameters.vmssName.value
$vmCount = $paramData.parameters.instanceCount.value
$vmSku =  $paramData.parameters.vmSku.value
$vmssSku =  $paramData.parameters.vmssSku.value
$adminUsername =  $paramData.parameters.adminUsername.value
$adminPassword =  $paramData.parameters.adminPassword.value
$vnetName = "vth-vnet"
$nsgName = $paramData.parameters.networkSecurityGroupName.value
$productName = $paramData.parameters.productName.value
$publisherName = $paramData.parameters.publisherName.value
$vThunderImage = $paramData.parameters.vThunderImage.value
$version = "latest"
$lbName = $paramData.parameters.lbName.value
$lbPubIPName = $paramData.parameters.lbPubIPName.value
$lbFEName = $paramData.parameters.lbFrontEndName.value
$lbBEPoolName = $paramData.parameters.lbBackEndPoolName.value
$storageAccountName = $paramData.parameters.storageAccountName.value
$vmName = $paramData.parameters.vmName.value
$workspaceName = "vth-vmss-log-workspace"
$appInsightName = "vth-vmss-app-insights"
$automationAccountName = $paramData.parameters.automationAccountName.value

#Create new resource group for deployment
New-AzResourceGroup -Name $resourceGroupName -Location $location

#Create storage account
$storageAccObj = New-AzStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName -Location $location -SkuName Standard_RAGRS -Kind StorageV2 -AssignIdentity

#Create storage account Container
New-AzStorageContainer -Name $paramData.parameters.sslContainerName.value -Permission Off -Context $storageAccObj.Context

New-AzStorageContainer -Name $paramData.parameters.logAgentContainerName.value -Permission Off -Context $storageAccObj.Context

# Create the workspace
New-AzOperationalInsightsWorkspace -Location $location -Name $workspaceName -ResourceGroupName $resourceGroupName
# create automation account
New-AzAutomationAccount -Name $automationAccountName -Location $location -ResourceGroupName $resourceGroupName

$workingDir = Get-Location

$changePasswordRunbookPath = -join($workingDir,"\", "PS_TMPL_3NIC_NVM_VMSS_CHANGE_PASSWORD_RUNBOOK.ps1")

$paramsChangePassword = @{
    AutomationAccountName = $automationAccountName
    Name                  = 'Change-Password-Config'
    ResourceGroupName     = $resourceGroupName
    Type                  = 'PowerShell'
    Path                  = $changePasswordRunbookPath
}
Import-AzAutomationRunbook -Published @paramsChangePassword

$slbRunbookPath = -join($workingDir,"\", "PS_TMPL_3NIC_NVM_VMSS_SLB_RUNBOOK.ps1")
$paramsSLBConfig = @{
    AutomationAccountName = $automationAccountName
    Name                  = 'SLB-Config'
    ResourceGroupName     = $resourceGroupName
    Type                  = 'PowerShell'
    Path                  = $slbRunbookPath
}
Import-AzAutomationRunbook -Published @paramsSLBConfig

$sslRunbookPath = -join($workingDir,"\", "PS_TMPL_3NIC_NVM_VMSS_SSL_RUNBOOK.ps1")
$paramsSSLConfig = @{
    AutomationAccountName = $automationAccountName
    Name                  = 'SSL-Config'
    ResourceGroupName     = $resourceGroupName
    Type                  = 'PowerShell'
    Path                  = $sslRunbookPath
}
Import-AzAutomationRunbook -Published @paramsSSLConfig

$glmRunbookPath = -join($workingDir,"\", "PS_TMPL_3NIC_NVM_VMSS_GLM_RUNBOOK.ps1")
$paramsGLMConfig = @{
    AutomationAccountName = $automationAccountName
    Name                  = 'GLM-Config'
    ResourceGroupName     = $resourceGroupName
    Type                  = 'PowerShell'
    Path                  = $glmRunbookPath
}
Import-AzAutomationRunbook -Published @paramsGLMConfig

$acosEventRunbookPath = -join($workingDir,"\", "PS_TMPL_3NIC_NVM_VMSS_ACOS_EVENT_CONFIG_RUNBOOK.ps1")
$paramsEventConfig = @{
    AutomationAccountName = $automationAccountName
    Name                  = 'Event-Config'
    ResourceGroupName     = $resourceGroupName
    Type                  = 'PowerShell'
    Path                  = $acosEventRunbookPath
}
Import-AzAutomationRunbook -Published @paramsEventConfig

$glmRevokeRunbookPath = -join($workingDir,"\", "PS_TMPL_3NIC_NVM_VMSS_GLM_REVOKE_RUNBOOK.ps1")
$paramsGLMRevokeConfig = @{
    AutomationAccountName = $automationAccountName
    Name                  = 'GLM-Revoke-Config'
    ResourceGroupName     = $resourceGroupName
    Type                  = 'PowerShell'
    Path                  = $glmRevokeRunbookPath
}
Import-AzAutomationRunbook -Published @paramsGLMRevokeConfig

$masterRunbookPath = -join($workingDir,"\", "PS_TMPL_3NIC_NVM_VMSS_MASTER_RUNBOOK.ps1")
$paramsMasterRunbook = @{
    AutomationAccountName = $automationAccountName
    Name                  = 'Master-Runbook'
    ResourceGroupName     = $resourceGroupName
    Type                  = 'PowerShell'
    Path                  = $masterRunbookPath
}
Import-AzAutomationRunbook -Published @paramsMasterRunbook


# Create application Insights
New-AzApplicationInsights -ResourceGroupName $resourceGroupName -Name $appInsightName -location $location

# Create subnet
$mgmtsubnet = New-AzVirtualNetworkSubnetConfig -Name "mgmtSubnet" -AddressPrefix $paramData.parameters.mgmtIntfPrivatePrefix.value
$data1subnet = New-AzVirtualNetworkSubnetConfig -Name "data1subnet" -AddressPrefix $paramData.parameters.eth1PrivatePrefix.value
$data2subnet = New-AzVirtualNetworkSubnetConfig -Name "data2subnet" -AddressPrefix $paramData.parameters.eth2PrivatePrefix.value

#Create vnet
$vNet = New-AzVirtualNetwork -Force -Name $vnetName -ResourceGroupName $resourceGroupName  -Location $location -AddressPrefix "10.0.0.0/16" -Subnet $mgmtsubnet,$data1subnet,$data2subnet
$vNet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName

$subNetId1 = $vNet.Subnets[0].Id
$subNetId2 = $vNet.Subnets[1].Id
$subNetId3 = $vNet.Subnets[2].Id

## Create load balance public ip
$publicIP = @{
    Name = $lbPubIPName
    ResourceGroupName = $resourceGroupName
    Location = $location
    Sku = 'Standard'
    AllocationMethod = 'static'
    Zone = 1
}
New-AzPublicIpAddress @publicIP

# logAgent machine public ip
$logAgentPIP = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Dynamic -IdleTimeoutInMinutes 4 -Name "logagentpip$(Get-Random)"

# Get public ip object
$publicIP = Get-AzPublicIpAddress -Name $lbPubIPName -ResourceGroupName $resourceGroupName

# Create lb frontend ip config
$lbFE = New-AzLoadBalancerFrontendIpConfig -Name $lbFEName -PublicIpAddress $publicIP

# Cretate lb backend address pool 
$backendAddressPool = New-AzLoadBalancerBackendAddressPoolConfig -Name $lbBEPoolName

# Create lb probe config
$healthProbe80 = New-AzLoadBalancerProbeConfig -Name 'HealthProbe80' -Protocol Tcp -Port 80 -IntervalInSeconds 15 -ProbeCount 2
$healthProbe443 = New-AzLoadBalancerProbeConfig -Name 'HealthProbe443' -Protocol Tcp -Port 443 -IntervalInSeconds 15 -ProbeCount 2
$healthProbe53 = New-AzLoadBalancerProbeConfig -Name 'HealthProbe53' -Protocol Tcp -Port 53 -IntervalInSeconds 15 -ProbeCount 2

# Create lb rule config
$lbRule80 = New-AzLoadBalancerRuleConfig -Name 'rulePort80' `
    -FrontendIPConfiguration $lbFE -BackendAddressPool $backendAddressPool `
    -Probe $healthProbe80 -Protocol Tcp -FrontendPort 80 -BackendPort 80 `
    -IdleTimeoutInMinutes 15

$lbRule443 = New-AzLoadBalancerRuleConfig -Name 'rulePort443' `
    -FrontendIPConfiguration $lbFE -BackendAddressPool $backendAddressPool `
    -Probe $healthProbe443 -Protocol Tcp -FrontendPort 443 -BackendPort 443 `
    -IdleTimeoutInMinutes 15

$lbRule53 = New-AzLoadBalancerRuleConfig -Name 'rulePort53' `
    -FrontendIPConfiguration $lbFE -BackendAddressPool $backendAddressPool `
    -Probe $healthProbe53 -Protocol Tcp -FrontendPort 53 -BackendPort 53 `
    -IdleTimeoutInMinutes 15

# Create LB
$lb = New-AzLoadBalancer -Name $lbName -ResourceGroupName $resourceGroupName -Location $location -Sku "Standard" `
    -FrontendIpConfiguration $lbFE -BackendAddressPool $backendAddressPool `
    -Probe $healthProbe80, $healthProbe443, $healthProbe53 -LoadBalancingRule $lbRule80, $lbRule443, $lbRule53

# Get lb object
$expectedLb = Get-AzLoadBalancer -Name $lbName -ResourceGroupName $resourceGroupName

#Create IPCOnfig for NIC1
# To add DNS setting in nic add the "-DnsSetting $paramData.parameters.dnsLabelPrefix1.value next to -Name Param"

$IPCfg1 = 
New-AzVmssIPConfig -Name "ipconfig1" -SubnetId $subNetId1 -Primary $True `
 -PublicIPAddressConfigurationName $paramData.parameters.nic1PublicIPName.value `
 -PublicIPAddressConfigurationIdleTimeoutInMinutes 15

#Create IPCOnfig for NIC2
$IPCfg2 = 
New-AzVmssIPConfig -Name "ipconfig2" -SubnetId $subNetId2 `
 -LoadBalancerBackendAddressPoolsId $expectedLb.BackendAddressPools[0].Id

#Create IPCOnfig for NIC3
$IPCfg3 = 
New-AzVmssIPConfig -Name "ipconfig3" -SubnetId $subNetId3

# Create an inbound network security group rule for port 22
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name "myNetworkSecurityGroupRuleSSH"  -Protocol "Tcp" -Direction "Inbound" -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access "Allow"
# Create an inbound network security group rule for port 80
$nsgRuleWebHttp = New-AzNetworkSecurityRuleConfig -Name "myNetworkSecurityGroupRuleHttp"  -Protocol "Tcp" -Direction "Inbound" -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access "Allow"
# Create an inbound network security group rule for port 443
$nsgRuleWebHttps = New-AzNetworkSecurityRuleConfig -Name "myNetworkSecurityGroupRuleHttps"  -Protocol "Tcp" -Direction "Inbound" -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443 -Access "Allow"
# Create an inbound network security group rule for ping
$nsgRuleWebPing = New-AzNetworkSecurityRuleConfig -Name "myNetworkSecurityGroupRulePing"  -Protocol "Icmp" -Direction "Inbound" -Priority 1003 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange * -Access "Allow"
# Create an inbound network security group rule for port 123(NTP)
$nsgRuleWebNtp = New-AzNetworkSecurityRuleConfig -Name "myNetworkSecurityGroupRuleNtp"  -Protocol "Udp" -Direction "Inbound" -Priority 1004 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 123 -Access "Allow"
# Create an inbound network security group rule for port 161(SNMP)
$nsgRuleWebSnmp = New-AzNetworkSecurityRuleConfig -Name "myNetworkSecurityGroupRuleSnmp"  -Protocol "Udp" -Direction "Inbound" -Priority 1005 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 161 -Access "Allow"

# Create a network security group
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name $nsgName -SecurityRules $nsgRuleSSH,$nsgRuleWebHttp,$nsgRuleWebHttps,$nsgRuleWebPing,$nsgRuleWebNtp,$nsgRuleWebSnmp

# Create a virtual network card and associate with public IP address and NSG
$logAgentNI = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name "logagentni" -Location $location -SubnetId $subNetId1 -PublicIpAddressId $logAgentPIP.Id -NetworkSecurityGroupId $nsg.Id

# Define a credential object
$securePassword = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($adminUsername, $securePassword)

# Start building the VM configuration
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSku

#Create the rest of configuration
$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $vmName -Credential $cred

$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName "canonical" -Offer "0001-com-ubuntu-server-focal" -Skus "20_04-lts-gen2" -Version "latest"

# for bootdiag
$vmConfig = Set-AzVMBootDiagnostic -VM $vmconfig -Enable -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName

#Attach NI
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $logAgentNI.Id -Primary

#Creating VM with all configuration
New-AzVM -ResourceGroupName $ResourceGroupName -Location $location -VM $vmConfig

# Create vmss config
$vmssConfig = New-AzVmssConfig -Location $location -Overprovision $False -Zone @(1) -SinglePlacementGroup $True `
-SkuName $vmssSku -SkuTier "Standard" -SkuCapacity $vmCount -UpgradePolicyMode "Automatic" `
 -PlanName $vThunderImage -PlanProduct $productName -PlanPublisher $publisherName `
 | Set-AzVmssOSProfile -ComputerNamePrefix $vmssName -AdminUsername $adminUsername -AdminPassword $adminPassword `
 | Set-AzVmssStorageProfile -OsDiskCreateOption 'FromImage' -OsDiskCaching "ReadWrite" -OsDiskOsType "Linux" `
 -ManagedDisk "Standard_LRS" -ImageReferenceOffer $productName -ImageReferenceSku $vThunderImage `
 -ImageReferenceVersion $version -ImageReferencePublisher $publisherName `
 | Add-AzVmssNetworkInterfaceConfiguration -Name ($paramData.parameters.nic1Name.value + "MgmtSubnet") -Primary $True `
 -NetworkSecurityGroupId $nsg.Id -IPConfiguration $IPCfg1 `
 | Add-AzVmssNetworkInterfaceConfiguration -Name ($paramData.parameters.nic2Name.value + "Data1Subnet") `
 -NetworkSecurityGroupId $nsg.Id -IPConfiguration $IPCfg2 `
 | Add-AzVmssNetworkInterfaceConfiguration -Name ($paramData.parameters.nic3Name.value + "Data2Subnet") `
 -NetworkSecurityGroupId $nsg.Id -IPConfiguration $IPCfg3

#Create the VMSS
New-AzVmss -ResourceGroupName $resourceGroupName  -Name $vmssName -VirtualMachineScaleSet $vmssConfig