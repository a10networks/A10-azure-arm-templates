#Deploying azure VMSS from marketplace
<#
.PARAMETER resource group, location
    Name of resource group, location
.EXAMPLE
    To run script execute .\<name-of-script> <resource-group-name> <storage-account-name> <location-name>
.Description
    Script to create VNET, Subnet, Network Security Group
#>

Param (
     [Parameter(Mandatory=$True)]
     [String] $resourceGroupName,
     [Parameter(Mandatory=$True)]
     [String] $location
 )
#connect to azure portal
Connect-AzAccount

# Get parameters
$absoluteFilePath = -join($PSScriptRoot,"\", "PS_TMPL_VNET_SUBNET_NSG_PARAM.json")
$paramData = Get-Content -Raw -Path $absoluteFilePath | ConvertFrom-Json -AsHashtable
$virtualNetworkPrefix = $paramData.parameters.Virtual_Network_CIDR.value
$virtualNetworkName = $paramData.parameters.Virtual_Network.value

#Create new resource group for deployment
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Create subnets configuration 
$mgmtSubnetPrefix = $paramData.parameters.Subnet_Mgmt_CIDR.value
$eth1SubnetPrefix = $paramData.parameters.Subnet_DataIn_CIDR.value
$eth2SubnetPrefix = $paramData.parameters.Subnet_DataOut_CIDR.value
$mgmtSubnet = New-AzVirtualNetworkSubnetConfig -Name $paramData.parameters.SubnetManagement.value -AddressPrefix $mgmtSubnetPrefix
$data1Subnet = New-AzVirtualNetworkSubnetConfig -Name $paramData.parameters.SubnetDataIn.value -AddressPrefix $eth1SubnetPrefix
$data2Subnet = New-AzVirtualNetworkSubnetConfig -Name $paramData.parameters.SubnetDataOut.value -AddressPrefix $eth2SubnetPrefix

# Create a virtual network
New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name $virtualNetworkName -AddressPrefix $virtualNetworkPrefix -Subnet $mgmtSubnet,$data1Subnet,$data2Subnet

# Create an inbound network security group rule for port 22
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name "myNetworkSecurityGroupRuleSSH"  -Protocol "Tcp" -Direction "Inbound" -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access "Allow"
# Create an inbound network security group rule for port 80
$nsgRuleWeb = New-AzNetworkSecurityRuleConfig -Name "myNetworkSecurityGroupRuleWWW"  -Protocol "Tcp" -Direction "Inbound" -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access "Allow"
# Create an inbound network security group rule for port 443
$nsgRuleWebHttps = New-AzNetworkSecurityRuleConfig -Name "myNetworkSecurityGroupRuleHttps"  -Protocol "Tcp" -Direction "Inbound" -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443 -Access "Allow"
# Create an inbound network security group rule for ping
$nsgRuleWebPing = New-AzNetworkSecurityRuleConfig -Name "myNetworkSecurityGroupRulePing"  -Protocol "Icmp" -Direction "Inbound" -Priority 1003 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange * -Access "Allow"
# Create an inbound network security group rule for port 123(NTP)
$nsgRuleWebNtp = New-AzNetworkSecurityRuleConfig -Name "myNetworkSecurityGroupRuleNtp"  -Protocol "Udp" -Direction "Inbound" -Priority 1004 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 123 -Access "Allow"
# Create an inbound network security group rule for port 161(SNMP)
$nsgRuleWebSnmp = New-AzNetworkSecurityRuleConfig -Name "myNetworkSecurityGroupRuleSnmp"  -Protocol "Udp" -Direction "Inbound" -Priority 1005 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 161 -Access "Allow"


# Create a network security groups
New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name $paramData.parameters.Network_Security_Group_VM1.value -SecurityRules $nsgRuleSSH,$nsgRuleWeb,$nsgRuleWebHttps,$nsgRuleWebPing,$nsgRuleWebNtp,$nsgRuleWebSnmp
New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name $ParamData.parameters.Network_Security_Group_VM2.value -SecurityRules $nsgRuleSSH,$nsgRuleWeb,$nsgRuleWebHttps,$nsgRuleWebPing,$nsgRuleWebNtp,$nsgRuleWebSnmp
