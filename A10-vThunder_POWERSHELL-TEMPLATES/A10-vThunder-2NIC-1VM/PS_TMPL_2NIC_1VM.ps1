#Deploying azure VM from marketplace
<#
.PARAMETER resource group and location
Name of resource group and location
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
    [String] $location
)

Write-Host $resourceGroup
Write-Host $location

$absoluteFilePath = -join($PSScriptRoot,"\", "PS_TMPL_2NIC_1VM_PARAM.json")

$ParamData = Get-Content -Raw -Path $absoluteFilePath | ConvertFrom-Json -AsHashtable
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
$resourceGroupName = $ParamData.parameters.ResourceGroupName.value
$vnet = $ParamData.parameters.virtual_network.value
$subnet1Name = $ParamData.parameters.subnet1Name.value
$subnet2Name = $ParamData.parameters.subnet2Name.value
$nsg = $ParamData.parameters.networkSecurityGroupName.value
$publicIPAddressName = $ParamData.parameters.publicIPAddressName.value
$enableip_forwd = $ParamData.parameters.enableIPForwarding.value
$enableaccelrated_network = $ParamData.parameters.enableAcceleratedNetworking.value

#Create new resource group for deployment
New-AzResourceGroup -Name $resourceGroup -Location $location

# Retrieve the existing a virtual network
$vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnet

# Retrieve the existing a public IP address
$mgmtpip = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIPAddressName

# Retrieve the existing a network security group
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $nsg
Write-Host $nsg

# Create a virtual network card and associate with public IP address and NSG
$mgmtsubnet = $vnet.Subnets | Where-Object{ $_.Name -eq $subnet1Name }
$mgmtnic = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic1Name.value -Location $location -SubnetId $mgmtsubnet.Id -PublicIpAddressId $mgmtpip.Id -NetworkSecurityGroupId $nsg.Id

Write-Host $mgmtsubnet
Write-Host $mgmtnic
$data1subnet = $vnet.Subnets | Where-Object{ $_.Name -eq $subnet2Name }
$data1nic = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Name $ParamData.parameters.nic2Name.value -Location $location -SubnetId $data1subnet.Id 
Write-Host $data1subnet

# Enable/Disable IP_Forwarding and AcceleratedNetworking
$data1nic.EnableIPForwarding = $enableip_forwd
$data1nic.EnableAcceleratedNetworking = $enableaccelrated_network
$data1nic | Set-AzNetworkInterface

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
$vmConfig = Set-AzVMBootDiagnostic -VM $vmconfig -Enable -ResourceGroupName $resourceGroup

#Attach the NIC that are created
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $mgmtnic.Id -Primary 
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $data1nic.Id 

Get-AzMarketplaceTerms -Publisher $publisher_name -Product $product_name -Name $sku_name | Set-AzMarketplaceTerms -Accept

#Creating VM with all configuration
New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig
