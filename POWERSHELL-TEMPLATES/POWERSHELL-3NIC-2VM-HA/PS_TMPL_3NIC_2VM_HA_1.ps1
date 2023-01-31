<#
.PARAMETER resourceGroup
Name of resource group
.PARAMETER storageaccount
Name of storage account
.PARAMETER location
Location of resource group
.EXAMPLE
To run script execute .\<name-of-script> -resourceGroup <resource-group-name>
 -storageaccount <storage-account-name> -location <location>
.Description
Script to create 2 vThunder instances having 3 NICs
Created Resources:
    1. Resource Group
    2. Storage Account
    3. Interfaces
    4. Subnets
    5. Virtual Network
    6. Public IPs
    7. NSGs
    8. vThunder Instances
#>

# Get input from user
Param (
    [Parameter(Mandatory=$True)]
    [String] $resourceGroup,
    [Parameter(Mandatory=$True)]
    [String] $location
)

#connect to azure portal
Connect-AzAccount

# Get parameters
$ParamData = Get-Content -Raw -Path PS_TMPL_3NIC_2VM_HA_PARAM.json | ConvertFrom-Json -AsHashtable
$vm1Name = $ParamData.parameters.vmName_vthunder1.value
$vm2Name = $ParamData.parameters.vmName_vthunder2.value
$vmSize = $ParamData.parameters.vmSize.value
$addressPrefix = $ParamData.parameters.addressPrefix.value
$vnet = $ParamData.parameters.virtual_network.value
$storageaccount = $ParamData.parameters.storageAccountName.value

# print values
Write-Host "Resource Group Name: " $resourceGroup
Write-Host "Storage Account Name: " $storageaccount
Write-Host "Location: " $location
Write-Host "vThunder Instance 1: " $vm1Name
Write-Host "vThunder Instance 2: " $vm2Name
Write-Host "vThunder Size: " $vmSize

#Create new resource group for deployment
New-AzResourceGroup -Name $resourceGroup -Location $location

#Create storage account
New-AzStorageAccount -ResourceGroupName $resourceGroup -AccountName $storageaccount -Location $location -SkuName Standard_RAGRS -Kind StorageV2 -AssignIdentity

# Create subnets configuration for vthunder 1 and vthunder 2
$mgmtSubnetPrefix = $ParamData.parameters.mgmtIntfPrivatePrefix.value
$eth1SubnetPrefix = $ParamData.parameters.eth1PrivatePrefix.value
$eth2SubnetPrefix = $ParamData.parameters.eth2PrivatePrefix.value

$mgmtSubnet = New-AzVirtualNetworkSubnetConfig -Name $ParamData.parameters.vm1MgmtIntfName.value -AddressPrefix $mgmtSubnetPrefix
$data1Subnet = New-AzVirtualNetworkSubnetConfig -Name $ParamData.parameters.vm1Eth1Name.value -AddressPrefix $eth1SubnetPrefix
$data2Subnet = New-AzVirtualNetworkSubnetConfig -Name $ParamData.parameters.vm1Eth2Name.value -AddressPrefix $eth2SubnetPrefix

# Create a virtual network
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroup -Location $location -Name $vnet -AddressPrefix $addressPrefix -Subnet $mgmtSubnet,$data1Subnet,$data2Subnet

# Create a public IP address and specify a DNS name for vthunder 1
$vm1MgmtPIp = New-AzPublicIpAddress -ResourceGroupName $resourceGroup -Location $location -AllocationMethod Dynamic -IdleTimeoutInMinutes 4 -Name "vThunderIP$(Get-Random)"

# Create a public IP address and specify a DNS name for vthunder 2
$vm2MgmtPIp = New-AzPublicIpAddress -ResourceGroupName $resourceGroup -Location $location -AllocationMethod Dynamic -IdleTimeoutInMinutes 4 -Name "vThunderIP$(Get-Random)"

# Create an inbound network security group rule for port 22
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name "ssh"  -Protocol "Tcp" -Direction "Inbound" -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access "Allow"
# Create an inbound network security group rule for port 80
$nsgRuleWeb = New-AzNetworkSecurityRuleConfig -Name "http"  -Protocol "Tcp" -Direction "Inbound" -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access "Allow"
# Create an inbound network security group rule for port 443
$nsgRuleWebHttps = New-AzNetworkSecurityRuleConfig -Name "https"  -Protocol "Tcp" -Direction "Inbound" -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443 -Access "Allow"
# Create an inbound network security group rule for ping
$nsgRuleWebPing = New-AzNetworkSecurityRuleConfig -Name "ping"  -Protocol "Icmp" -Direction "Inbound" -Priority 1003 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange * -Access "Allow"
# Create an inbound network security group rule for port 123(NTP)
$nsgRuleWebNtp = New-AzNetworkSecurityRuleConfig -Name "ntp"  -Protocol "Udp" -Direction "Inbound" -Priority 1004 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 123 -Access "Allow"
# Create an inbound network security group rule for port 161(SNMP)
$nsgRuleWebSnmp = New-AzNetworkSecurityRuleConfig -Name "snmp"  -Protocol "Udp" -Direction "Inbound" -Priority 1005 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 161 -Access "Allow"


# Create a network security group vthunder 1
$vm1nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name $ParamData.parameters.networkSecurityGroupName_vm1.value -SecurityRules $nsgRuleSSH,$nsgRuleWeb,$nsgRuleWebHttps,$nsgRuleWebPing,$nsgRuleWebNtp,$nsgRuleWebSnmp
# Create a network security group vthunder 2
$vm2nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name $ParamData.parameters.networkSecurityGroupName_vm2.value -SecurityRules $nsgRuleSSH,$nsgRuleWeb,$nsgRuleWebHttps,$nsgRuleWebPing,$nsgRuleWebNtp,$nsgRuleWebSnmp

# Create a virtual network card and associate with public IP address and NSG for vthunder 1
$mgmtSubnet = $vnet.Subnets | Where-Object{ $_.Name -eq $ParamData.parameters.vm1MgmtIntfName.value }
$vm1MgmtNIC = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic1Name_vm1.value -Location $location -SubnetId $mgmtSubnet.Id -PublicIpAddressId $vm1MgmtPIp.Id -NetworkSecurityGroupId $vm1nsg.Id

$data1Subnet = $vnet.Subnets | Where-Object{ $_.Name -eq $ParamData.parameters.vm1Eth1Name.value }
$vm1Data1NIC = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic2Name_vm1.value -Location $location -SubnetId $data1Subnet.Id

# Get vthunder 3 nic slb parameter file content
$SLBParamData = Get-Content -Raw -Path PS_TMPL_3NIC_2VM_HA_SLB_CONFIG_PARAM.json | ConvertFrom-Json -AsHashtable
if ($null -eq $SLBParamData) {
    Write-Error "PS_TMPL_3NIC_2VM_HA_SLB_CONFIG_PARAM.json file is missing." -ErrorAction Stop
}
# Get VIP from slb config file
$vip = $SLBParamData.parameters.virtualServerList.'ip-address'

# check if vip is available
$isAvailable = Test-AzPrivateIPAddressAvailability -IPAddress $vip -VirtualNetwork $vnet
if (!$isAvailable.Available) {
    Write-Warning "VIP mentioned in slb configuration file" $vip "is not available."
    $vip = $isAvailable.AvailableIPAddresses[0]
    Write-Host "Adding available ip" $vip "as vip"
}
# Add vip is data interface 1
Add-AzNetworkInterfaceIpConfig -Name vip -NetworkInterface $vm1Data1NIC -Subnet $data1Subnet -PrivateIpAddress $vip
# Set data interface 1 with new ip configuration
Set-AzNetworkInterface -NetworkInterface $vm1Data1NIC


$data2Subnet = $vnet.Subnets | Where-Object{ $_.Name -eq $ParamData.parameters.vm1Eth2Name.value }
$vm1Data2NIC = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic3Name_vm1.value -Location $location -SubnetId $data2Subnet.Id

# Get floating
$fip = $vm1Data2NIC.IpConfigurations[0].PrivateIpAddress

# check if fip is available
$isAvailable = Test-AzPrivateIPAddressAvailability -IPAddress $fip -VirtualNetwork $vnet
if (!$isAvailable.Available) {
    $fip = $isAvailable.AvailableIPAddresses[0]
}
# Add vip is data interface 1
Add-AzNetworkInterfaceIpConfig -Name fip -NetworkInterface $vm1Data2NIC -Subnet $data2Subnet -PrivateIpAddress $fip
# Set data interface 1 with new ip configuration
Set-AzNetworkInterface -NetworkInterface $vm1Data2NIC


# Create a virtual network card and associate with public IP address and NSG for vthunder 2
$mgmtSubnet = $vnet.Subnets | Where-Object{ $_.Name -eq $ParamData.parameters.vm1MgmtIntfName.value }
$vm2MgmtNIC = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic1Name_vm2.value -Location $location -SubnetId $mgmtSubnet.Id -PublicIpAddressId $vm2MgmtPIp.Id -NetworkSecurityGroupId $vm2nsg.Id

$data1Subnet = $vnet.Subnets | Where-Object{ $_.Name -eq $ParamData.parameters.vm1Eth1Name.value}
$vm2Data1NIC = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic2Name_vm2.value -Location $location -SubnetId $data1Subnet.Id

$data2Subnet = $vnet.Subnets | Where-Object{ $_.Name -eq $ParamData.parameters.vm1Eth2Name.value }
$vm2Data2NIC = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic3Name_vm2.value -Location $location -SubnetId $data2Subnet.Id

# Define a credential object
$name = ConvertTo-SecureString -String $ParamData.parameters.adminUsername.value -AsPlainText -Force
$securePassword = ConvertTo-SecureString -String $ParamData.parameters.adminPassword.value -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($name, $securePassword)

# Start building the VM1 configuration
$vm1Config = New-AzVMConfig -VMName $vm1Name -VMSize $vmSize
# Start building the VM2 configuration
$vm2Config = New-AzVMConfig -VMName $vm2Name -VMSize $vmSize

#Create the rest of configuration for vthunder 1
$vm1Config = Set-AzVMOperatingSystem -VM $vm1Config -Linux -ComputerName $vm1Name -Credential $cred
$vm1Config = Set-AzVMSourceImage -VM $vm1Config -PublisherName $ParamData.parameters.publisherName.value -Offer $ParamData.parameters.productName.value -skus $ParamData.parameters.vThunderImage.value -Version "latest"
$vm1Config = Set-AzVMPlan -Name $ParamData.parameters.vThunderImage.value -Product $ParamData.parameters.productName.value -Publisher $ParamData.parameters.publisherName.value -VM $vm1config

#Create the rest of configuration for vthunder 2
$vm2Config = Set-AzVMOperatingSystem -VM $vm2Config -Linux -ComputerName $vm2Name -Credential $cred
$vm2Config = Set-AzVMSourceImage -VM $vm2Config -PublisherName $ParamData.parameters.publisherName.value -Offer $ParamData.parameters.productName.value -skus $ParamData.parameters.vThunderImage.value -Version "latest"
$vm2Config = Set-AzVMPlan -Name $ParamData.parameters.vThunderImage.value -Product $ParamData.parameters.productName.value -Publisher $ParamData.parameters.publisherName.value -VM $vm2config


# for bootdiag
$vm1Config = Set-AzVMBootDiagnostic -VM $vm1config -Enable -ResourceGroupName $resourceGroup -StorageAccountName $storageaccount
# for bootdiag
$vm2Config = Set-AzVMBootDiagnostic -VM $vm2config -Enable -ResourceGroupName $resourceGroup -StorageAccountName $storageaccount

#Attach the NIC that are created for vthunder 1
$vm1Config = Add-AzVMNetworkInterface -VM $vm1Config -Id $vm1MgmtNIC.Id -Primary 
$vm1Config = Add-AzVMNetworkInterface -VM $vm1Config -Id $vm1Data1NIC.Id 
$vm1Config = Add-AzVMNetworkInterface -VM $vm1Config -Id $vm1Data2NIC.Id

#Attach the NIC that are created for vthunder 2
$vm2Config = Add-AzVMNetworkInterface -VM $vm2Config -Id $vm2MgmtNIC.Id -Primary 
$vm2Config = Add-AzVMNetworkInterface -VM $vm2Config -Id $vm2Data1NIC.Id 
$vm2Config = Add-AzVMNetworkInterface -VM $vm2Config -Id $vm2Data2NIC.Id


#Creating VM1 with all configuration
New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $vm1Config
#Creating VM2 with all configuration
New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $vm2Config