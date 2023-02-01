#Deploying azure VM from marketplace
<#
.PARAMETER resource group, storage account, location
Name of resource group, storage account and location
.EXAMPLE
To run script execute .\<name-of-script> <resource-group-name> <storage-account-name> <location-name>
.Description
Script to create vthunder instance
#>

# Get resource group name
Param (
    [Parameter(Mandatory=$True)]
    [String] $resourceGroup,
    [Parameter(Mandatory=$True)]
    [String] $storageaccount,
    [Parameter(Mandatory=$True)]
    [String] $location
)

Write-Host $resourceGroup
Write-Host $storageaccount
Write-Host $location

$ParamData = Get-Content -Raw -Path PS_TMPL_2NIC_1VM_PARAM.json | ConvertFrom-Json -AsHashtable
if ($null -eq $ParamData) {
    Write-Error "PS_TMPL_2NIC_1VM_PARAM.json file is missing." -ErrorAction Stop
}

#login into azure
Login-AzAccount

$vmName = $ParamData.parameters.vmName.value
Write-Host $vmName
$vmSize = $ParamData.parameters.vmSize.value
Write-Host $vmSize
$publisher_name = $ParamData.parameters.publisherName.value
$product_name = $ParamData.parameters.productName.value
$sku_name = $ParamData.parameters.vThunderImage.value
Write-Host $sku_name
$vnet = $ParamData.parameters.virtual_network.value

#Create new resource group for deployment
New-AzResourceGroup -Name $resourceGroup -Location $location

#Create storage account
New-AzStorageAccount -ResourceGroupName $resourceGroup -AccountName $storageaccount -Location $location -SkuName Standard_RAGRS -Kind StorageV2 -AssignIdentity

# Create a subnet configuration
$mgmtsubnet = New-AzVirtualNetworkSubnetConfig -Name "mgmtSubnet" -AddressPrefix $ParamData.parameters.mgmtIntfPrivatePrefix.value
$data1subnet = New-AzVirtualNetworkSubnetConfig -Name "data1subnet" -AddressPrefix $ParamData.parameters.eth1PrivatePrefix.value
Write-Host $mgmtsubnet
Write-Host $data1subnet

# Create a virtual network
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroup -Location $location -Name $vnet -AddressPrefix $ParamData.parameters.addressPrefixValue.value -Subnet $mgmtsubnet,$data1subnet

# Create a public IP address and specify a DNS name
$mgmtpip = New-AzPublicIpAddress -ResourceGroupName $resourceGroup -Location $location -AllocationMethod Dynamic -IdleTimeoutInMinutes 4 -Name "myip$(Get-Random)"
$data1pip = New-AzPublicIpAddress -ResourceGroupName $resourceGroup -Location $location -AllocationMethod Dynamic -IdleTimeoutInMinutes 4 -Name "myip$(Get-Random)"


# Create an inbound network security group rule for port 22
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name "ssh"  -Protocol "Tcp" -Direction "Inbound" -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access "Allow"
# Create an inbound network security group rule for port 80
$nsgRuleWebHttp = New-AzNetworkSecurityRuleConfig -Name "http"  -Protocol "Tcp" -Direction "Inbound" -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access "Allow"
# Create an inbound network security group rule for port 443
$nsgRuleWebHttps = New-AzNetworkSecurityRuleConfig -Name "https"  -Protocol "Tcp" -Direction "Inbound" -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443 -Access "Allow"
# Create an inbound network security group rule for ping
$nsgRuleWebPing = New-AzNetworkSecurityRuleConfig -Name "ping"  -Protocol "Icmp" -Direction "Inbound" -Priority 1003 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange * -Access "Allow"
# Create an inbound network security group rule for port 123(NTP)
$nsgRuleWebNtp = New-AzNetworkSecurityRuleConfig -Name "ntp"  -Protocol "Udp" -Direction "Inbound" -Priority 1004 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 123 -Access "Allow"
# Create an inbound network security group rule for port 161(SNMP)
$nsgRuleWebSnmp = New-AzNetworkSecurityRuleConfig -Name "snmp"  -Protocol "Udp" -Direction "Inbound" -Priority 1005 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 161 -Access "Allow"

# Create a network security group
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name $ParamData.parameters.networkSecurityGroupName.value -SecurityRules $nsgRuleSSH,$nsgRuleWebHttp,$nsgRuleWebHttps,$nsgRuleWebPing,$nsgRuleWebNtp,$nsgRuleWebSnmp
Write-Host $nsg
# Create a virtual network card and associate with public IP address and NSG
$mgmtsubnet = $vnet.Subnets | Where-Object{ $_.Name -eq 'mgmtsubnet' }
$mgmtnic = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic1Name.value -Location $location -SubnetId $mgmtsubnet.Id -PublicIpAddressId $mgmtpip.Id -NetworkSecurityGroupId $nsg.Id

Write-Host $mgmtsubnet
Write-Host $mgmtnic
$data1subnet = $vnet.Subnets | Where-Object{ $_.Name -eq 'data1subnet' }
$data1nic = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic2Name.value -Location $location -SubnetId $data1subnet.Id -PrivateIpAddress $ParamData.parameters.eth1PrivateAddress.value
Write-Host $data1subnet
Write-Host $data1nic
# Define a credential object
$name = ConvertTo-SecureString -String $ParamData.parameters.adminUsername.value -AsPlainText -Force
$securePassword = ConvertTo-SecureString -String $ParamData.parameters.adminPassword.value -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($name, $securePassword)

Write-Host $name
Write-Host $securePassword
Write-Host $cred

# Start building the VM configuration
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize

#Create the rest of configuration 
$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $vmName -Credential $cred
$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $publisher_name -Offer $product_name -skus $sku_name -Version "latest"
$vmConfig = Set-AzVMPlan -Name $sku_name -Product $product_name -Publisher $publisher_name -VM $vmconfig

# for bootdiag
$vmConfig = Set-AzVMBootDiagnostic -VM $vmconfig -Enable -ResourceGroupName $resourceGroup -StorageAccountName $storageaccount

#Attach the NIC that are created
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $mgmtnic.Id -Primary 
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $data1nic.Id 

Get-AzMarketplaceTerms -Publisher $publisher_name -Product $product_name -Name $sku_name | Set-AzMarketplaceTerms -Accept

#Creating VM with all configuration
New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig
