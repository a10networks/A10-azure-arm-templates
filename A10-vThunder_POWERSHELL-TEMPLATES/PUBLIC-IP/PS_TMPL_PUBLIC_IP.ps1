#Deploying azure VMSS from marketplace
<#
.PARAMETER resource group, location
    Name of resource group, location
.EXAMPLE
    To run script execute .\<name-of-script> <resource-group-name> <location-name>
.Description
    Script to create Public IP's
#>

Param (
     [Parameter(Mandatory=$True)]
     [String] $resourceGroupName,
     [Parameter(Mandatory=$True)]
     [String] $location
 )

# Get config data from param file
$absoluteFilePath = -join($PSScriptRoot,"\", "PS_TMPL_PUBLIC_IP_PARAM.json")
$paramData = Get-Content -Raw -Path $absoluteFilePath | ConvertFrom-Json

#get parameters value from parameter file
$PublicIpName1 = $ParamData.parameters.Public_IP_Name_VM1.value
$PublicIpName2 = $ParamData.parameters.Public_IP_Name_VM2.value
$PublicIpName3 = $ParamData.parameters.Public_IP_Name_VIP.value
$DomainName1 = $ParamData.parameters.DNS_VM1.value
$DomainName2 = $ParamData.parameters.DNS_VM2.value
$DomainName3 = $ParamData.parameters.DNS_VM3.value

# Authenticate with Azure Portal
Connect-AzAccount

#Create new resource group for deployment
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Create public IP's and specify a DNS name
New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name $PublicIpName1 -DomainNameLabel $DomainName1 -Sku Standard -Zone 1, 2, 3
New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name $PublicIpName2 -DomainNameLabel $DomainName2 -Sku Standard -Zone 1, 2, 3
New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name $PublicIpName3 -DomainNameLabel $DomainName3 -Sku Standard -Zone 1, 2, 3
