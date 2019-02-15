#Deploying azure VM from marketplace
Login-AzureRmAccount

$location = Read-Host 'Enter the location'
$resourceGroup = Read-Host 'Enter resource group name'
$storageaccount = Read-Host 'Enter storage account name'
$vmName = Read-Host 'VM Name'
$vmSize = Read-Host 'Enter VM size'

#Create new resource group for deployment
New-AzureRmResourceGroup -Name $resourceGroup -Location $location

#Create storage account
New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -AccountName $storageaccount -Location $location -SkuName Standard_RAGRS -Kind StorageV2 -AssignIdentity

# Create a subnet configuration
$mgmtsubnet = New-AzureRmVirtualNetworkSubnetConfig -Name "mgmtSubnet" -AddressPrefix "192.168.1.0/24"
$data1subnet = New-AzureRmVirtualNetworkSubnetConfig -Name "data1subnet" -AddressPrefix "192.168.2.0/24"
$data2subnet = New-AzureRmVirtualNetworkSubnetConfig -Name "data2subnet" -AddressPrefix "192.168.3.0/24"

# Create a virtual network
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location -Name "TestVnet" -AddressPrefix 192.168.0.0/16 -Subnet $mgmtsubnet,$data1subnet,$data2subnet

# Create a public IP address and specify a DNS name
$mgmtpip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location -AllocationMethod Dynamic -IdleTimeoutInMinutes 4 -Name "myip$(Get-Random)"
$data1pip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location -AllocationMethod Dynamic -IdleTimeoutInMinutes 4 -Name "myip$(Get-Random)"
$data2pip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location -AllocationMethod Dynamic -IdleTimeoutInMinutes 4 -Name "myip$(Get-Random)"

# Create an inbound network security group rule for port 22
$nsgRuleSSH = New-AzureRmNetworkSecurityRuleConfig -Name "myNetworkSecurityGroupRuleSSH"  -Protocol "Tcp" -Direction "Inbound" -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access "Allow"
# Create an inbound network security group rule for port 80
$nsgRuleWeb = New-AzureRmNetworkSecurityRuleConfig -Name "myNetworkSecurityGroupRuleWWW"  -Protocol "Tcp" -Direction "Inbound" -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access "Allow"

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name "myNetworkSecurityGroup" -SecurityRules $nsgRuleSSH,$nsgRuleWeb

# Create a virtual network card and associate with public IP address and NSG
$mgmtsubnet = $vnet.Subnets | ?{ $_.Name -eq 'mgmtsubnet' }
$mgmtnic = New-AzureRmNetworkInterface -ResourceGroupName $resourceGroup -Name "mgmtnic" -Location $location -SubnetId $mgmtsubnet.Id -PublicIpAddressId $mgmtpip.Id -NetworkSecurityGroupId $nsg.Id

$data1subnet = $vnet.Subnets | ?{ $_.Name -eq 'data1subnet' }
$data1nic = New-AzureRmNetworkInterface -ResourceGroupName $resourceGroup -Name "data1nic" -Location $location -SubnetId $data1subnet.Id -PublicIpAddressId $data1pip.Id -NetworkSecurityGroupId $nsg.Id

$data2subnet = $vnet.Subnets | ?{ $_.Name -eq 'data2subnet' }
$data2nic = New-AzureRmNetworkInterface -ResourceGroupName $resourceGroup -Name "data2nic" -Location $location -SubnetId $data2subnet.Id -PublicIpAddressId $data2pip.Id -NetworkSecurityGroupId $nsg.Id

# Define a credential object
$name= Read-Host 'Enter Username' 
$securePassword = Read-Host 'Enter the password' -AsSecureString
$cred = New-Object System.Management.Automation.PSCredential ($name, $securePassword)

# Start building the VM configuration
$vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize

#Create the rest of configuration 
$vmConfig = Set-AzureRmVMOperatingSystem -VM $vmConfig -Linux -ComputerName $vmName -Credential $cred
$vmConfig = Set-AzureRmVMSourceImage -VM $vmConfig -PublisherName "a10networks" -Offer "a10-vthunder-adc" -skus "vthunder_500mbps" -Version "latest"
$vmConfig = Set-AzureRmVMPlan -Name "vthunder_500mbps" -Product "a10-vthunder-adc" -Publisher "a10networks" -VM $vmconfig

# for bootdiag
$vmConfig = Set-AzureRmVMBootDiagnostics -VM $vmconfig -Enable -ResourceGroupName $resourceGroup -StorageAccountName $storageaccount

#Attach the NIC that are created
$vmConfig = Add-AzureRmVMNetworkInterface -VM $vmConfig -Id $mgmtnic.Id -Primary 
$vmConfig = Add-AzureRmVMNetworkInterface -VM $vmConfig -Id $data1nic.Id 
$vmConfig = Add-AzureRmVMNetworkInterface -VM $vmConfig -Id $data2nic.Id

#Creating VM with all configuration
New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig