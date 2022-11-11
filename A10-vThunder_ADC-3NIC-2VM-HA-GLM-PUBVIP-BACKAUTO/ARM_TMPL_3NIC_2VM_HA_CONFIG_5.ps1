<#
.PARAMETER resource group
Name of resource group
.EXAMPLE
To run script execute .\<name-of-script> <resource-group-name>
.Description
Script to enable HA between 2 vthunder instances.
Functions:
    1. Get-AuthToken
    2. VrrpACommonConfiguration 
    3. TerminalTimeoutConfiguration
    4. VrrpAVridConfiguration
    5. PeerGroupConfiguration
    6. WriteMemory
#>

# Get resource group name
$resData = Get-Content -Raw -Path ARM_TMPL_3NIC_2VM_AUTOMATION_ACCOUNT_PARAM.json | ConvertFrom-Json -AsHashtable
Write-Output $resData

if ($null -eq $resData) {
    Write-Error "resData data is missing." -ErrorAction Stop
}

$resourceGroupName = $resData.resourceGroupName

Write-Host "Executing 3NIC-HA-Configuration"

# check if resource group is present
if ($null -eq $resourceGroupName) {
    Write-Error "Resource Group name is missing" -ErrorAction Stop
}

# Connect to Azure portal
$status = $null
$status = Connect-AzAccount
if ($null -eq $status) {
    Write-Error "Authentication with Azure Portal Failed" -ErrorAction Stop
}

# Get vthunder 3 nic parameter file content
$ParamData = Get-Content -Raw -Path ARM_TMPL_3NIC_2VM_PARAM.json | ConvertFrom-Json -AsHashtable
if ($null -eq $ParamData) {
    Write-Error "ARM_TMPL_3NIC_2VM_PARAM.json file is missing." -ErrorAction Stop
}

# Get vthunder 3 nic HA parameter file content
$HAParamData = Get-Content -Raw -Path ARM_TMPL_3NIC_2VM_HA_CONFIG_PARAM.json | ConvertFrom-Json -AsHashtable
if ($null -eq $HAParamData) {
    Write-Error "ARM_TMPL_3NIC_2VM_HA_CONFIG_PARAM.json file is missing." -ErrorAction Stop
}

# Get vthunder 3 nic slb parameter file content
$SLBParamData = Get-Content -Raw -Path ARM_TMPL_3NIC_2VM_SLB_CONFIG_PARAM.json | ConvertFrom-Json -AsHashtable
if ($null -eq $SLBParamData) {
    Write-Error "ARM_TMPL_3NIC_2VM_SLB_CONFIG_PARAM.json file is missing." -ErrorAction Stop
}

# Get arguments
$host1MgmtName = $ParamData.parameters.nic1Name_vthunder1.value
$host2MgmtName = $ParamData.parameters.nic1Name_vthunder2.value

# Get vThunder1 IP Address
$response = Get-AzNetworkInterface -Name $host1MgmtName -ResourceGroupName $resourceGroupName
$host1IPName = $response.IpConfigurations.PublicIpAddress.Id.Split('/')[-1]
$response = Get-AzPublicIpAddress -Name $host1IPName -ResourceGroupName $resourceGroupName
if ($null -eq $response) {
    Write-Error "Failed to get public ip" -ErrorAction Stop
}
$host1IPAddress = $response.IpAddress
Write-Host "vThunder1 Public IP: "$host1IPAddress

# Get vThunder2 IP Address
$response = Get-AzNetworkInterface -Name $host2MgmtName -ResourceGroupName $resourceGroupName
$host2IPName = $response.IpConfigurations.PublicIpAddress.Id.Split('/')[-1]
$response = Get-AzPublicIpAddress -Name $host2IPName -ResourceGroupName $resourceGroupName
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
    `n        `"username`": `"admin`",
    `n        `"password`": `"a10`"
    `n    }
    `n}"
    # Invoke Auth url
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $headers -Body $body
    # fetch Authorization token from response
    $AuthorizationToken = $Response.authresponse.signature
    if ($null -eq $AuthorizationToken) {
        Write-Error "Falied to get authorization token from AXAPI" -ErrorAction Stop
    }
    return $AuthorizationToken
}

function PrimaryDNSConfig {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        vThunder auth token
        .DESCRIPTION
        Function to do primary dns configuration
        AXAPI: /ip/dns/primary
    #>
    param (
        $BaseUrl,
        $AuthorizationToken
    )
    # AXAPI Url
    $Url = -join($BaseUrl, "/ip/dns/primary")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    # get dns value from HA config file
    $dns = $HAParamData.parameters.dns.value

    # payload for AXAPI
    $body = @{
        "primary" = @{
            "ip-v4-addr" = $dns 
          }
    }
    # convert into json format
    $body = $body | ConvertTo-Json -Depth 6

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $body
    if ($null -eq $response) {
        Write-Error "Failed to configure primary dns"
    } else {
        Write-Host "Configured primary dns"
    }
}

function IPRouteConfig {
    param (
        $BaseUrl,
        $AuthorizationToken
    )
    # AXAPI Url
    $Url = -join($BaseUrl, "/ip/route/rib")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    # get rib list from HA config
    $ribList = $HAParamData.parameters."rib-list"

    # payload for AXAPI
    $body = @{
        "rib-list" = $ribList
    } 

    # convert into json format
    $body = $body | ConvertTo-Json -Depth 6

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $body
    if ($null -eq $response) {
        Write-Error "Failed to configure ip route"
    } else {
        Write-Host "Configured ip route"
    }
}

function VrrpACommonConfiguration {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        vThunder auth token
        .PARAMETER DeviceID
        DeviceID for HA vrrp-a group
        .DESCRIPTION
        Function to do vrrp-a common configuration
        AXAPI: /vrrp-a/common
    #>
    param (
        $BaseUrl,
        $AuthorizationToken,
        $DeviceID
    )
    # AXAPI Url
    $Url = -join($BaseUrl, "/vrrp-a/common")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    # get set id from HA configuration file
    $setID = $HAParamData.parameters.'vrrp-a'.'set-id'
    
    # payload for AXAPI
    $body = @{
        "common" = @{
            "device-id"=$DeviceID
            "set-id"=$setID
            "action"="enable"
          }
    }
    # convert into json format
    $body = $body | ConvertTo-Json -Depth 6

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $body
    if ($null -eq $response) {
        Write-Error "Failed to configure vrrp-a common configuration"
    } else {
        Write-Host "Configured vrrp-a common"
    }
}

function TerminalTimeoutConfiguration {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        vThunder auth token
        .DESCRIPTION
        Function to do terminal timeout configuration
        AXAPI: /terminal
    #>
    param (
        $BaseUrl,
        $AuthorizationToken
    )
    # AXAPI Url
    $Url = -join($BaseUrl, "/terminal")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    # get timeout from HA configuration file
    $timeout = $HAParamData.parameters.terminal.'idle-timeout'

    # payload for AXAPI
    $body = @{
        "terminal"= @{
            "idle-timeout"=$timeout
          }
    }
    # convert into json format
    $body = $body | ConvertTo-Json -Depth 6
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $body
    if ($null -eq $response) {
        Write-Error "Failed to configure terminal timeout"
    } else {
        Write-Host "Configured terminal timeout"
    }
}


function VrrpAVridConfiguration {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        vThunder auth token
        .PARAMETER index
        Int for decrementing default priority
        .DESCRIPTION
        Function to do vrid configuration
        AXAPI: /vrrp-a/vrid
    #>
    param (
        $BaseUrl,
        $AuthorizationToken,
        $index
    )
    # AXAPI Url
    $Url = -join($BaseUrl, "/vrrp-a/vrid")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    # get vrid-list value from HA configuration 
    $vridList = $HAParamData.parameters.'vrid-list'
    $vridList.'blade-parameters'.priority -= $index

    # get floating ip (vip) from SLB configuration file
    $floatingIP = $SLBParamData.parameters.virtualServerList.'ip-address'
    $floatingIPJson = @{
        "ip-address" = $floatingIP
    }

    # type cast array into array list
    $vridArrayList = [System.Collections.ArrayList] $vridList[0].'floating-ip'.'ip-address-cfg'
    $vridArrayList.Add($floatingIPJson)
    # replace array with array list
    $vridList[0].'floating-ip'.'ip-address-cfg' = $vridArrayList

    # payload for AXAPI
    $body = @{
        "vrid-list" = $vridList
    }
    # convert body into json format
    $body = $body | ConvertTo-Json -Depth 6
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $body
    if ($null -eq $response) {
        Write-Error "Failed to configure vrid"
    } else {
        Write-Host "Configured vrid"
    }
}

function PeerGroupConfiguration {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        vThunder auth token
        .PARAMETER vm1Name
        key name from parameter json file
        .PARAMETER vm2Name
        key name from parameter json file
        .DESCRIPTION
        Function to do peer group configuration
        AXAPI: /vrrp-a/peer-group
    #>
    param (
        $BaseUrl,
        $AuthorizationToken,
        $vm1Name,
        $vm2Name
    )
    # AXAPI Url
    $Url = -join($BaseUrl, "/vrrp-a/peer-group")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    # VM1 data1 interface name
    $vm1InterfaceName = $ParamData.parameters.nic2Name_vm1.value

    # Get Network Interface IP Address
    $vm1Name = $ParamData.parameters.$vm1Name.value
    $vm1Info = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vm1Name
    $vm1Interfaces = $vm1Info.NetworkProfile.NetworkInterfaces.Id

    # VM2 data2 interface name
    $vm2InterfaceName = $ParamData.parameters.nic2Name_vm2.value

    # Get Network Interface IP Address
    $vm2Name = $ParamData.parameters.$vm2Name.value
    $vm2Info = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vm2Name
    $vm2Interfaces = $vm2Info.NetworkProfile.NetworkInterfaces.Id

    # Peer group list
    $ipPeerAddressList = New-Object System.Collections.ArrayList
    
    # get private ip address of client interface vm1
    foreach ($interface in $vm1Interfaces) {
        # get interface private ip
        $interfaceName = $interface.Split('/')[-1]
        if ($interfaceName -match $vm1InterfaceName) {    
            $interfaceInfo = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $interfaceName
            $ethPrivateIpAddress = $interfaceInfo.IpConfigurations[0].PrivateIpAddress
            $peerAddress = @{
                "ip-peer-address" = $ethPrivateIpAddress
            }
            $ipPeerAddressList.Add($peerAddress)
            break
        }
    }

    # get private ip address of client interface vm1
    foreach ($interface in $vm2Interfaces) {
        # get interface private ip
        $interfaceName = $interface.Split('/')[-1]
        if ($interfaceName -match $vm2InterfaceName) {    
            $interfaceInfo = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $interfaceName
            $ethPrivateIpAddress = $interfaceInfo.IpConfigurations[0].PrivateIpAddress
            $peerAddress = @{
                "ip-peer-address" = $ethPrivateIpAddress
            }
            $ipPeerAddressList.Add($peerAddress)
            break
        }
    }

    # Payload for AXAPI
    $body = @{
        "peer-group" = @{
            "peer" = @{
                "ip-peer-address-cfg" = $ipPeerAddressList
            }
        }
    }

    # convert from hashmap to json
    $body = $body | ConvertTo-Json -Depth 6
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $body
    if ($null -eq $response) {
        Write-Error "Failed to configure peer-group"
    } else {
        Write-Host "Configured peer-group"
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

# Configure both vThunder vms as SLB
$index = 0
$deviceID = 1
$vms = @($host1IPAddress, $host2IPAddress)
$vmNames = @("vmName_vthunder1", "vmName_vthunder2")
foreach ($vm in $vms) {
    # Base URL of AXAPIs
    $vthunderBaseUrl = -join("https://", $vm, "/axapi/v3")
    # Call above functions
    # Invoke Get-AuthToken
    $AuthorizationToken = Get-AuthToken -BaseUrl $vthunderBaseUrl
    # Invoke PrimaryDNSConfig for both VMs
    PrimaryDNSConfig -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken
    # Invoke IPRouteConfig for both VMs
    IPRouteConfig -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken
    # Invoke VrrpACommonConfiguration for both VMs
    VrrpACommonConfiguration -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -DeviceID $deviceID
    # Invoke TerminalTimeoutConfiguration
    TerminalTimeoutConfiguration -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken
    # Invoke VrrpAVridConfiguration
    VrrpAVridConfiguration -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -index $index
    # Invoke PeerGroupConfiguration
    PeerGroupConfiguration -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -vm1Name $vmNames[0] -vm2Name $vmNames[1]
    # Invoke WriteMemory
    WriteMemory -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken
    # increment index
    $index += 1
    $deviceID += 1
    Write-Host "Configured HA on vThunder Instance "$index
}
