<#
.PARAMETER resource group
Name of resource group
.EXAMPLE
To run script execute .\<name-of-script> <resource-group-name>
.Description
Script to enable HA between 2 vthunder instances.
Functions:
    1. GetAuthToken
    2. PrimaryDNSConfig
    3. IPRouteConfig
    4. VrrpACommonConfiguration 
    5. TerminalTimeoutConfiguration
    6. VrrpAVridConfiguration
    7. PeerGroupConfiguration
    8. WriteMemory
    9. VThLogout
#>

Write-Host "Executing HA-Configurations"

# Get HA parameter file content
$absoluteFilePath = -join($PSScriptRoot,"\", "HA_CONFIG_PARAM.json")
$haParamData = Get-Content -Raw -Path $absoluteFilePath | ConvertFrom-Json -AsHashtable
if ($null -eq $haParamData) {
    Write-Error "HA_CONFIG_PARAM.json file is missing." -ErrorAction Stop
}

#Get vThunder username
$vThUsername = $haParamData.parameters.vThUsername

#Get vThunder public IP list
$hostIPAddress = $haParamData.parameters.hostIPAddress.vThunderIP

function GetAuthToken {
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
        $baseUrl,
        $password
    )
    # AXAPI Auth url 
    $url = -join($baseUrl, "/auth")
    # AXAPI header
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    # AXAPI Auth url json body
    $body = "{
    `n    `"credentials`": {
    `n        `"username`": `"$vThUsername`",
    `n        `"password`": `"$password`"
    `n    }
    `n}"
    # Invoke Auth url
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
    # fetch Authorization token from response
    $authorizationToken = $response.authresponse.signature
    if ($null -eq $authorizationToken) {
        Write-Error "Falied to get authorization token from AXAPI" -ErrorAction Stop
    }
    return $authorizationToken
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
        $baseUrl,
        $authorizationToken
    )
    # AXAPI Url
    $url = -join($baseUrl, "/ip/dns/primary")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    # get dns value from HA config file
    $dns = $haParamData.parameters.dns.value

    # payload for AXAPI
    $body = @{
        "primary" = @{
            "ip-v4-addr" = $dns 
          }
    }
    # convert into json format
    $body = $body | ConvertTo-Json -Depth 6

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
    if ($null -eq $response) {
        Write-Error "Failed to configure primary dns"
    } else {
        Write-Host "Configured primary dns"
    }
}

function IPRouteConfig {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        vThunder auth token
        .DESCRIPTION
        Function to configure IP route
        AXAPI: /ip/route/rib
    #>

    param (
        $baseUrl,
        $authorizationToken
    )
    # AXAPI Url
    $url = -join($baseUrl, "/ip/route/rib")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    # get rib list from HA config
    $ribList = $haParamData.parameters."rib-list"

    # payload for AXAPI
    $body = @{
        "rib-list" = $ribList
    } 

    # convert into json format
    $body = $body | ConvertTo-Json -Depth 6

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
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
        $baseUrl,
        $authorizationToken,
        $deviceID
    )
    # AXAPI Url
    $url = -join($baseUrl, "/vrrp-a/common")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    # get set id from HA configuration file
    $setID = $haParamData.parameters.'vrrp-a'.'set-id'
    
    # payload for AXAPI
    $body = @{
        "common" = @{
            "device-id"=$deviceID
            "set-id"=$setID
            "action"="enable"
          }
    }
    # convert into json format
    $body = $body | ConvertTo-Json -Depth 6

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
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
        $baseUrl,
        $authorizationToken
    )
    # AXAPI Url
    $url = -join($baseUrl, "/terminal")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    # get timeout from HA configuration file
    $timeout = $haParamData.parameters.terminal.'idle-timeout'

    # payload for AXAPI
    $body = @{
        "terminal"= @{
            "idle-timeout"=$timeout
          }
    }
    # convert into json format
    $body = $body | ConvertTo-Json -Depth 6
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
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
        $baseUrl,
        $authorizationToken,
        $index
    )
    # AXAPI Url
    $url = -join($baseUrl, "/vrrp-a/vrid")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    # get vrid-list value from HA configuration 
    $vridList = $haParamData.parameters.'vrid-list'
    $vridList.'blade-parameters'.priority -= $index

    # get floating ip (vip) from SLB configuration file
    $floatingIP = $haParamData.parameters.vip
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
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
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
        $baseUrl,
        $authorizationToken,
        $vm1Name,
        $vm2Name
    )
    # AXAPI Url
    $url = -join($baseUrl, "/vrrp-a/peer-group")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    $ethPrivateIpAddressVm1 = $haParamData.parameters.eth1PrivateIpAddressVm1
    $ethPrivateIpAddressVm2 = $haParamData.parameters.eth1PrivateIpAddressVm2


    # Peer group list
    $ipPeerAddressList = New-Object System.Collections.ArrayList
    $peerAddress = @{
        "ip-peer-address" = $ethPrivateIpAddressVm1
    }
    $ipPeerAddressList.Add($peerAddress)
    $peerAddress = @{
        "ip-peer-address" = $ethPrivateIpAddressVm2
    }
    $ipPeerAddressList.Add($peerAddress)

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
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
    if ($null -eq $response) {
        Write-Error "Failed to configure peer-group"
    } else {
        Write-Host "Configured peer-group"
    }
}

function InterfaceMgmt {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        vThunder auth token
    #>
    param (
        $baseUrl,
        $authorizationToken
    )
    # AXAPI Url


    $url = -join($baseUrl, "/interface/management")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    $body = @{
        "management" = @{
            "ip" = @{
                "control-apps-use-mgmt-port" = 1
            }
        }
    }

    # convert from hashmap to json
    $body = $body | ConvertTo-Json -Depth 6
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
    if ($null -eq $response) {
        Write-Error "Failed to configure interface management"
    } else {
        Write-Host "Configured interface management"
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
        $baseUrl,
        $authorizationToken
    )
    $url = -join($baseUrl, "/active-partition")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'GET' -Headers $headers
    $partition = $response.'active-partition'.'partition-name'

    if ($null -eq $partition) {
        Write-Error "Failed to get partition name"
    } else {
        $url = -join($baseUrl, "/write/memory")
        $headers.Add("Content-Type", "application/json")

        $body = "{
        `n  `"memory`": {
        `n    `"partition`": `"$partition`"
        `n  }
        `n}"
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
        if ($null -eq $response) {
            Write-Error "Failed to run write memory command"
        } else {
            Write-Host "Configurations are saved on partition: "$partition
        }
    }
}

function VThLogout{
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
        $baseUrl,
        $vThunderIP,
        $authorizationToken
    )

    $url = -join($baseUrl, "/logoff")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))

    $response = Invoke-RestMethod -Method 'GET' -SkipCertificateCheck -Uri $url -Headers $headers

    if ($null -eq $response) {
        Write-Error "Failed to closed Session ID for $vthunderIP."
    } else {
        Write-Host "Session ID closed for $vthunderIP."
    }

}

#Configuring HA on vThunder's
$index = 0
$deviceID = 1
$vmNames = @("vmName_vthunder1", "vmName_vthunder2")

foreach ($vm in $hostIPAddress) {
    # Base URL of AXAPIs
    $vthunderBaseUrl = -join("https://", $vm, "/axapi/v3")
    # Call above functions

    #Get vThunder username and password
    $vThNewPasswordVal = Read-Host "Enter Password for $vm " -AsSecureString
    $vThNewPassword = ConvertFrom-SecureString -SecureString $vThNewPasswordVal -AsPlainText

    # Invoke Get-AuthToken
    $authorizationToken = GetAuthToken -BaseUrl $vthunderBaseUrl -password $vThNewPassword
    # Invoke PrimaryDNSConfig for both VMs
    PrimaryDNSConfig -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken
    # Invoke IPRouteConfig for both VMs
    IPRouteConfig -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken
    # Invoke VrrpACommonConfiguration for both VMs
    VrrpACommonConfiguration -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken -DeviceID $deviceID
    # Invoke TerminalTimeoutConfiguration
    TerminalTimeoutConfiguration -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken
    # Invoke VrrpAVridConfiguration
    VrrpAVridConfiguration -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken -index $index
    # Invoke PeerGroupConfiguration
    PeerGroupConfiguration -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken -vm1Name $vmNames[0] -vm2Name $vmNames[1]
    # Invoke InterfaceMgmt
    InterfaceMgmt -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken
    # Invoke WriteMemory
    WriteMemory -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken
    # increment index
    $index += 1
    $deviceID += 1
    Write-Host "Configured HA on vThunder Instance "$index
    #Invoke VThLogout
    VThLogout -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken -vthunderIP $vm
        Write-Host "--------------------------------------------------------------------------------------------------------------------"

}
