<#
.PARAMETER resourceGroup
Name of resource group
.PARAMETER location
Location of resource group
.EXAMPLE
To run script execute .\<name-of-script> -resourceGroup <resource-group-name>
 -storageaccount <storage-account-name> -location <location>
.Description
Script to create 2 vThunder instances having 3 NICs
Created Resources:
    1. Resource Group
    2. Interfaces
    3. vThunder Instances
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
$absoluteFilePath = -join($PSScriptRoot,"\", "PS_TMPL_3NIC_2VM_PVTVIP_PARAM.json")
$ParamData = Get-Content -Raw -Path $absoluteFilePath | ConvertFrom-Json -AsHashtable
$vm1Name = $ParamData.parameters.vmName_vthunder1.value
$vm2Name = $ParamData.parameters.vmName_vthunder2.value
$vm1Zone = $ParamData.parameters.thunder1Zone.value
$vm2Zone = $ParamData.parameters.thunder2Zone.value
$vmSize = $ParamData.parameters.vmSize.value
$resourceGroupName = $ParamData.parameters.ResourceGroupName.value
$vnet = $ParamData.parameters.virtual_network.value
$subnet1Name = $ParamData.parameters.subnet1Name.value
$subnet2Name = $ParamData.parameters.subnet2Name.value
$subnet3Name = $ParamData.parameters.subnet3Name.value
$vm1nsg = $ParamData.parameters.networkSecurityGroupName_vm1.value
$vm2nsg = $ParamData.parameters.networkSecurityGroupName_vm2.value
$PublicIPName_vm1 = $ParamData.parameters.PublicIPName_vm1.value
$PublicIPName_vm2 = $ParamData.parameters.PublicIPName_vm2.value
$enableaccelrated_network = $ParamData.parameters.enableAcceleratedNetworking.value
$enableip_forwd = $ParamData.parameters.enableIPForwarding.value

# print values
Write-Host "Resource Group Name: " $resourceGroup
Write-Host "Location: " $location
Write-Host "vThunder Instance 1: " $vm1Name
Write-Host "vThunder Instance 2: " $vm2Name
Write-Host "vThunder Size: " $vmSize

#Create new resource group for deployment
New-AzResourceGroup -Name $resourceGroup -Location $location

# Retrieve the existing a virtual network	
$vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnet

# Retrieve the existing a public IP address
$vm1MgmtPIp = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $PublicIPName_vm1

# Retrieve the existing a public IP address
$vm2MgmtPIp = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $PublicIPName_vm2

# Retrieve the existing a network security group of vthunder 1
$vm1nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $vm1nsg
# Retrieve the existing a network security group of vthunder 2
$vm2nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $vm2nsg

# Create a virtual network card and associate with public IP address and NSG for vthunder 1
$mgmtSubnet = $vnet.Subnets | Where-Object{ $_.Name -eq $subnet1Name }
$vm1MgmtNIC = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic1Name_vm1.value -Location $location -SubnetId $mgmtSubnet.Id -PublicIpAddressId $vm1MgmtPIp.Id -NetworkSecurityGroupId $vm1nsg.Id

$data1Subnet = $vnet.Subnets | Where-Object{ $_.Name -eq $subnet2Name }
$vm1Data1NIC = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic2Name_vm1.value -Location $location -SubnetId $data1Subnet.Id

# Enable/Disable IP_Forwarding and AcceleratedNetworking for NIC1
$vm1Data1NIC.EnableIPForwarding = $enableip_forwd
$vm1Data1NIC.EnableAcceleratedNetworking = $enableaccelrated_network
$vm1Data1NIC | Set-AzNetworkInterface

# Get VIP
$vip = $vm1Data1NIC.IpConfigurations.PrivateIpAddress

# check if vip is available
$isAvailable = Test-AzPrivateIPAddressAvailability -IPAddress $vip -VirtualNetwork $vnet
if (!$isAvailable.Available){
    $vip = $isAvailable.AvailableIPAddresses[0]
    Write-Host "Adding available ip" $vip "as vip"
}

# Add vip is data interface 1
Add-AzNetworkInterfaceIpConfig -Name vip -NetworkInterface $vm1Data1NIC -Subnet $data1Subnet -PrivateIpAddress $vip

# Set data interface 1 with new ip configuration
Set-AzNetworkInterface -NetworkInterface $vm1Data1NIC

$data2Subnet = $vnet.Subnets | Where-Object{ $_.Name -eq $subnet3Name }
$vm1Data2NIC = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic3Name_vm1.value -Location $location -SubnetId $data2Subnet.Id

# Enable/Disable IP_Forwarding and AcceleratedNetworking for NIC2
$vm1Data2NIC.EnableIPForwarding = $enableip_forwd
$vm1Data2NIC.EnableAcceleratedNetworking = $enableaccelrated_network
$vm1Data2NIC | Set-AzNetworkInterface

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
$mgmtSubnet = $vnet.Subnets | Where-Object{ $_.Name -eq $subnet1Name }
$vm2MgmtNIC = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic1Name_vm2.value -Location $location -SubnetId $mgmtSubnet.Id -PublicIpAddressId $vm2MgmtPIp.Id -NetworkSecurityGroupId $vm2nsg.Id

$data1Subnet = $vnet.Subnets | Where-Object{ $_.Name -eq $subnet2Name }
$vm2Data1NIC = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic2Name_vm2.value -Location $location -SubnetId $data1Subnet.Id

# Enable/Disable IP_Forwarding and AcceleratedNetworking for NIC1
$vm2Data1NIC.EnableIPForwarding = $enableip_forwd
$vm2Data1NIC.EnableAcceleratedNetworking = $enableaccelrated_network
$vm2Data1NIC | Set-AzNetworkInterface

$data2Subnet = $vnet.Subnets | Where-Object{ $_.Name -eq $subnet3Name }
$vm2Data2NIC = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic3Name_vm2.value -Location $location -SubnetId $data2Subnet.Id

# Enable/Disable IP_Forwarding and AcceleratedNetworking for NIC2
$vm2Data2NIC.EnableIPForwarding = $enableip_forwd
$vm2Data2NIC.EnableAcceleratedNetworking = $enableaccelrated_network
$vm2Data2NIC | Set-AzNetworkInterface

# Define a credential object
$name = ConvertTo-SecureString -String $ParamData.parameters.adminUsername.value -AsPlainText -Force
$securePassword = ConvertTo-SecureString -String $ParamData.parameters.adminPassword.value -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($name, $securePassword)

# Start building the VM1 configuration
$vm1Config = New-AzVMConfig -VMName $vm1Name -VMSize $vmSize -Zone $vm1Zone
# Start building the VM2 configuration
$vm2Config = New-AzVMConfig -VMName $vm2Name -VMSize $vmSize -Zone $vm2Zone

#Create the rest of configuration for vthunder 1
$vm1Config = Set-AzVMOperatingSystem -VM $vm1Config -Linux -ComputerName $vm1Name -Credential $cred
$vm1Config = Set-AzVMSourceImage -VM $vm1Config -PublisherName $ParamData.parameters.publisherName.value -Offer $ParamData.parameters.productName.value -skus $ParamData.parameters.vThunderImage.value -Version "latest"
$vm1Config = Set-AzVMPlan -Name $ParamData.parameters.vThunderImage.value -Product $ParamData.parameters.productName.value -Publisher $ParamData.parameters.publisherName.value -VM $vm1config

#Create the rest of configuration for vthunder 2
$vm2Config = Set-AzVMOperatingSystem -VM $vm2Config -Linux -ComputerName $vm2Name -Credential $cred
$vm2Config = Set-AzVMSourceImage -VM $vm2Config -PublisherName $ParamData.parameters.publisherName.value -Offer $ParamData.parameters.productName.value -skus $ParamData.parameters.vThunderImage.value -Version "latest"
$vm2Config = Set-AzVMPlan -Name $ParamData.parameters.vThunderImage.value -Product $ParamData.parameters.productName.value -Publisher $ParamData.parameters.publisherName.value -VM $vm2config


# for bootdiag
$vm1Config = Set-AzVMBootDiagnostic -VM $vm1config -Enable -ResourceGroupName $resourceGroup 
# for bootdiag
$vm2Config = Set-AzVMBootDiagnostic -VM $vm2config -Enable -ResourceGroupName $resourceGroup

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