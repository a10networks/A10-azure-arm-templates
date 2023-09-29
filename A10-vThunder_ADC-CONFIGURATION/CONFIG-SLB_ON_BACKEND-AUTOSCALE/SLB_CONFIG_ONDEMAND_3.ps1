<#
.PARAMETER resource group
Name of resource group
.EXAMPLE
To run script execute .\<name-of-script>
.Description
Script to configure a thunder instance as SLB.
Functions:
    1. Get-AuthToken
    2. ConfigureEthernets 
    3. ConfigureServer
    4. ConfigureServiceGroup
    5. ConfigureVirtualServer
    6. WriteMemory
#>

# Get resource group name
$absoluteAmFilePath = -join($PSScriptRoot,"\", "CREATE_AUTOMATION_ACCOUNT_PARAM.json")
$resData = Get-Content -Raw -Path $absoluteAmFilePath | ConvertFrom-Json -AsHashtable

if ($null -eq $resData) {
    Write-Error "resData data is missing." -ErrorAction Stop
}

$resourceGroupName = $resData.resourceGroupName
$vnetresourceGroupName = $resData.vnetresourceGroupName

# check if resource group is present
if ($null -eq $resourceGroupName) {
    Write-Error "Resource Group name is missing" -ErrorAction Stop
}

$vThUsername = $resData.vThUsername
$vThNewPasswordVal = Read-Host "Enter vThunder Password" -AsSecureString
$vThNewPassword = ConvertFrom-SecureString -SecureString $vThNewPasswordVal -AsPlainText

Write-Host "Executing 3NIC-SLB-Configuration"

# Connect to Azure portal
$status = $null
$status = Connect-AzAccount
if ($null -eq $status) {
    Write-Error "Authentication with Azure Portal Failed" -ErrorAction Stop
}

# Get SLB_CONFIG_ONDEMAND_PARAM parameter file content
$absoluteSlbFilePath = -join($PSScriptRoot,"\", "SLB_CONFIG_ONDEMAND_PARAM.json")
$SLBParamData = Get-Content -Raw -Path $absoluteSlbFilePath | ConvertFrom-Json -AsHashtable
if ($null -eq $SLBParamData) {
    Write-Error "SLB_CONFIG_ONDEMAND_PARAM.json file is missing." -ErrorAction Stop
}


# Get arguments from parameter file
$host1MgmtName = $resData.mgmtInterface1
$host2MgmtName = $resData.mgmtInterface2
# get arguments from slb paramter file
$virtualServer = $SLBParamData.parameters.virtualServerList

# Print variables
Write-Host "Virtual Server Name: " $virtualServer.'virtual-server-name'
Write-Host "Resource Group Name: " $resourceGroupName

# Get vThunder1 IP Address
$response = Get-AzNetworkInterface -Name $host1MgmtName -ResourceGroupName $resourceGroupName
$host1IPName = $response.IpConfigurations.PublicIpAddress.Id.Split('/')[-1]
$response = Get-AzPublicIpAddress -Name $host1IPName -ResourceGroupName $vnetresourceGroupName
if ($null -eq $response) {
    Write-Error "Failed to get public ip" -ErrorAction Stop
}
$host1IPAddress = $response.IpAddress
Write-Host "vThunder1 Public IP: "$host1IPAddress

# Get vThunder2 IP Address
$response = Get-AzNetworkInterface -Name $host2MgmtName -ResourceGroupName $resourceGroupName
$host2IPName = $response.IpConfigurations.PublicIpAddress.Id.Split('/')[-1]
$response = Get-AzPublicIpAddress -Name $host2IPName -ResourceGroupName $vnetresourceGroupName
if ($null -eq $response) {
    Write-Error "Failed to get public ip" -ErrorAction Stop
}
$host2IPAddress = $response.IpAddress
Write-Host "vThunder2 Public IP: "$host2IPAddress


function Get-AuthToken {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .OUTPUTS
        Authorization token
        .DESCRIPTION
        Function to get Authorization token
        AXAPI: /axapi/v3/auth
    #>
    param (
        $BaseUrl
    )
    # AXAPI Auth url
    $Url = -join($BaseUrl, "/auth")
    # AXAPI header
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    # AXAPI Auth url json body
    $Body = "{
    `n    `"credentials`": {
    `n        `"username`": `"$vThUsername`",
    `n        `"password`": `"$vThNewPassword`"
    `n    }
    `n}"
    # Invoke Auth url
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $headers -Body $body
    # fetch Authorization token from response
    $AuthorizationToken = $response.authresponse.signature
    if ($null -eq $AuthorizationToken) {
        Write-Error "Falied to get authorization token from AXAPI" -ErrorAction Stop
    }
    return $AuthorizationToken
}

# Function to enable ethernet 1
function ConfigureEthernets {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to configure ethernet1 private ip
        AXAPI: /axapi/v3/interface/ethernet/{ethernet}
    #>
    param (
        $BaseUrl,
        $AuthorizationToken,
        $vmName
    )
    
    # AXAPI interface url headers
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    # get vthunder name
    $vmName = $resData.$vmName
    Write-Host "Configuring vm: "$vmName

    # for each interface, get private ip address and add configuration in ethernet list
    for ($ethernetNumber=1; $ethernetNumber -le 2; $ethernetNumber++) {
        # AXAPI ethernets Url
        $Url = -join($BaseUrl, "/interface/ethernet/"+$ethernetNumber)
    
        # ethernet configuration
        $body = @{
            "ethernet"= @{
                "ifnum" = $ethernetNumber
                "action" = "enable"
                "ip" = @{
                    "dhcp" = 1
                    }
                }
            }
            
        # convert body to json
        $body = $body | ConvertTo-Json -Depth 6
        # Invoke interface AXAPI
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $body
        if ($null -eq $response) {
            Write-Error "Failed to configure ethernet-"$ethernetNumber" ip"
        } else {
            Write-Host "configured ethernet-"$ethernetNumber" ip"
        }
    }
}

function ConfigureServiceGroup {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to configure service group
        AXAPI: /axapi/v3/slb/service-group
    #>
    param (
        $BaseUrl,
        $AuthorizationToken
    )
    $Url = -join($BaseUrl, "/slb/service-group")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    $ServiceGroups = $SLBParamData.parameters.serviceGroupList.value
    $Body = @{
        "service-group-list"= $ServiceGroups
    }
    $Body = $Body | ConvertTo-Json -Depth 6
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
    if ($null -eq $response) {
        Write-Error "Failed to configure service group"
    } else {
        Write-Host "Configured service group"   
    }
}

function ConfigureVirtualServer {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to configure virtual server
        AXAPI: /axapi/v3/slb/virtual-server
    #>
    param (
        $BaseUrl,
        $AuthorizationToken
    )
    $Url = -join($BaseUrl, "/slb/virtual-server")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")
    
    $VirtualServerPorts = $SLBParamData.parameters.virtualServerList.value

    $VirtualServer = @{
                "name" = $VirtualServer.'virtual-server-name'
                "ip-address"=$SLBParamData.parameters.virtualServerList.'ip-address'
    }
    $VirtualServer.Add("port-list", $VirtualServerPorts)
    $VirtualServerList = New-Object System.Collections.ArrayList
    $VirtualServerList.Add($VirtualServer)
    $Body = @{}
    $Body.Add("virtual-server-list", $VirtualServerList)

    $Body = $Body | ConvertTo-Json -Depth 6
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
    if ($null -eq $response) {
        Write-Error "Failed to configure virtual server"
    } else {
        Write-Host "Configured virtual server"   
    }
}

function WriteMemory {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to save configurations on active partition
        AXAPI: /axapi/v3/active-partition
        AXAPI: /axapi/v3//write/memory
    #>
    param (
        $BaseUrl,
        $AuthorizationToken
    )
    $Url = -join($BaseUrl, "/active-partition")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'GET' -Headers $Headers
    $partition = $response.'active-partition'.'partition-name'

    if ($null -eq $partition) {
        Write-Error "Failed to get partition name"
    } else {
        $Url = -join($BaseUrl, "/write/memory")
        $Headers.Add("Content-Type", "application/json")

        $Body = "{
        `n  `"memory`": {
        `n    `"partition`": `"$partition`"
        `n  }
        `n}"
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
        if ($null -eq $response) {
            Write-Error "Failed to run write memory command"
        } else {
            Write-Host "Configurations are saved on partition: "$partition
        }
    }
}

function vth_logout{
        <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to logout the session
        AXAPI: /axapi/v3/logoff
    #>
    param (
        $BaseUrl,
        $vthunderIP,
        $AuthorizationToken
    )

    $Url = -join($BaseUrl, "/logoff")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $AuthorizationToken))

    $response = Invoke-RestMethod -Method 'GET' -SkipCertificateCheck -Uri $Url -Headers $headers

    if ($null -eq $response) {
        Write-Error "Failed to closed Session ID for $vthunderIP."
    } else {
        Write-Host "Session ID closed for $vthunderIP."
    }

}

# Configure both vThunder vms as SLB
$index = 0
$vms = @($host1IPAddress, $host2IPAddress)
$vmNames = @("vThunderName1", "vThunderName2")
foreach ($vm in $vms) {
    # Base URL of AXAPIs
    $vthunderBaseUrl = -join("https://", $vm, "/axapi/v3")
    # Call above functions
    # Invoke Get-AuthToken
    $AuthorizationToken = Get-AuthToken -BaseUrl $vthunderBaseUrl
    # Invoke Configure Ethernets for both VMs
    ConfigureEthernets -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -vmName $vmNames[$index]
    # Invoke ConfigureServiceGroup
    ConfigureServiceGroup -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken
    # Invoke ConfigureVirtualServer
    ConfigureVirtualServer -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken

    # Invoke WriteMemory
    WriteMemory -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken
    # increment index
    $index += 1
    Write-Host "Configured vThunder Instance "$index
    vth_logout -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -vthunderIP $vm
}
