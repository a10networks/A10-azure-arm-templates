<#
.PARAMETER resource group
Name of resource group
.EXAMPLE
To run script execute .\<name-of-script> <resource-group-name>
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

# Get vthunder slb parameter file content
$absoluteFilePath = -join($PSScriptRoot,"\", "SLB_CONFIG_PARAM.json")
$slbParamData = Get-Content -Raw -Path $absoluteFilePath | ConvertFrom-Json -AsHashtable
if ($null -eq $slbParamData) {
    Write-Error "SLB_CONFIG_PARAM.json file is missing." -ErrorAction Stop
}

# get arguments from slb paramter file
$vThUsername = $slbParamData.parameters.vThUsername
$hostIPAddress = $slbParamData.parameters.hostIPAddress.vThunderIP
$interfaceCount = $slbParamData.parameters.dataInterfaceCount
$slbServerHostOrDomain = $slbParamData.parameters.slbServerHostOrDomain
$virtualServer = $slbParamData.parameters.virtualServerList

# Print variables
if ($null -ne $slbServerHostOrDomain.host) {
    Write-Host "SLB Server Host IP: " $slbServerHostOrDomain.host
}
elseif ($null -ne $slbServerHostOrDomain.'fqdn-name') {
    Write-Host "SLB Server Domain: " $slbServerHostOrDomain.'fqdn-name'
}

function getAuthToken {
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
        $baseUrl,
        $authorizationToken,
        $vmName,
        $count
    )
    
    # AXAPI interface url headers
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    # get vthunder name
    Write-Host "Configuring vthunder"

    # for each interface, get private ip address and add configuration in ethernet list
    for ($ethernetNumber=1; $ethernetNumber -le $count; $ethernetNumber++) {
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
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
        if ($null -eq $response) {
            Write-Error "Failed to configure ethernet-"$ethernetNumber" ip"
        } else {
            Write-Host "configured ethernet-"$ethernetNumber" ip"
        }

    }
}

# Create server s1
function ConfigureServer {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to configure server
        AXAPI: /axapi/v3/slb/server
    #>
    param (
        $baseUrl,
        $authorizationToken
    )
    # AXAPI Url
    $url = -join($baseUrl, "/slb/server")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")
    $server = $slbServerHostOrDomain.value
    $ports = $slbParamData.parameters.slbServerPortList.value
    

    for ($i = 0; $i -lt $server.Length; $i++){
        
        $body = @{
            "server"=@{}
        }
        $body.server.add('name', $server[$i].'server-name')
        if ($null -ne $server[$i].'host') {
            $body.server.add('host', $server[$i].'host')
        }
        elseif ($null -ne $server[$i].'fqdn-name') {
            $Body.server.add('fqdn-name', $server[$i].'fqdn-name')
        }
        else {
            Write-Error "host or fqdn-name is required in slb_parameter file"
            continue
        }
        $body.server.add('port-list', $ports) 
        
        $body = $Body | ConvertTo-Json -Depth 6

        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
        $server_name = $server[$i].'server-name'
        if ($null -eq $response) {
            Write-Error "Failed to configure server $server_name"
        } else {
            Write-Host "Configured server $server_name"
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
        $baseUrl,
        $authorizationToken
    )
    $url = -join($baseUrl, "/slb/service-group")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    $serviceGroups = $slbParamData.parameters.serviceGroupList.value
    $body = @{
        "service-group-list"= $serviceGroups
    }
    $body = $body | ConvertTo-Json -Depth 6
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
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
        $baseUrl,
        $authorizationToken,
        $virtualServerPorts
    )
    $url = -join($baseUrl, "/slb/virtual-server")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")
    $virtualServer = @{
        "name" = $virtualServer.'virtual-server-name'
        "ip-address"=$slbParamData.parameters.virtualServerList.'ip-address'
    }

    $virtualServer.Add("port-list", $virtualServerPorts)
    $virtualServerList = New-Object System.Collections.ArrayList
    $virtualServerList.Add($virtualServer)
    $body = @{}
    $body.Add("virtual-server-list", $virtualServerList)

    $body = $body | ConvertTo-Json -Depth 6
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
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
        Write-Error "Failed to closed Session ID for $vThunderIP."
    } else {
        Write-Host "Session ID closed for $vThunderIP."
    }

}

$index = 0
# Configure both vThunder vms as SLB
$vmNames = @("vmName_vthunder1", "vmName_vthunder2")

# Convert the "virtualServerList" "value" to an array of hashtables
$virtualServers = $slbParamData.parameters.virtualServerList.value

foreach ($vm in $hostIPAddress) {
    # Base URL of AXAPIs
    $vthunderBaseUrl = -join("https://", $vm, "/axapi/v3")
    
    #user input for vthunder password
    $vThNewPasswordVal = Read-Host "Enter Password for $vm " -AsSecureString
    $vThNewPassword = ConvertFrom-SecureString -SecureString $vThNewPasswordVal -AsPlainText

    # Call above functions
    # Invoke Get-AuthToken
    $AuthorizationToken = getAuthToken -BaseUrl $vthunderBaseUrl -password $vThNewPassword
    # Invoke Configure Ethernets for both VMs
    ConfigureEthernets -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken -vmName $vmNames[$index] -count $interfaceCount
    # Invoke CreateServer
    ConfigureServer -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken
    # Invoke ConfigureServiceGroup
    ConfigureServiceGroup -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken

    # Check if "HTTP-Template" is equal to 1
    if ($slbParamData.parameters.templateHTTP -eq 1) {
        # Load the HTTP_TEMPLATE.ps1 script to make the function available
        . ".\HTTP_TEMPLATE.ps1"

        # Call the function from HTTP_TEMPLATE.ps1
        CreateSlbTemplateHttp -baseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken
    } else {
        # Remove "template-http" from "virtualServerList" "value" list
        $virtualServers | ForEach-Object {
            if ($_.ContainsKey('template-http')) {
                $_.Remove('template-http')
            }
        }
    }

    # Check if "Persist-Cookie-Template" is equal to 1
    if ($slbParamData.parameters.templatePersistCookie -eq 1) {
        # Load the PERSIST_COOKIE_TEMPLATE.ps1 script to make the function available
        . ".\PERSIST_COOKIE_TEMPLATE.ps1"

        # Call the function from PERSIST_COOKIE_TEMPLATE.ps1
        CreateSlbPersistCookie -baseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken
   
    } else {
        # Remove "template-http" from "virtualServerList" "value" list
        $virtualServers | ForEach-Object {
            if ($_.ContainsKey('template-persist-cookie')) {
                $_.Remove('template-persist-cookie')
            }
        }
    }

    # Update the modified virtualServers array in the hashtable
    $slbParamData.parameters.virtualServerList.value = $virtualServers

    # Convert the modified hashtable back to JSON
    $modifiedJson = $slbParamData | ConvertTo-Json -Depth 10

    # Save the modified JSON back to the file
    $modifiedJson | Set-Content -Path $absoluteFilePath

    # Invoke ConfigureVirtualServer
    ConfigureVirtualServer -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken -count $interfaceCount -virtualServerPorts $virtualServers
    # Invoke WriteMemory
    WriteMemory -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken
    # increment index
    $index += 1
    Write-Host "Configured vThunder Instance "$index

    vThLogout -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken -vthunderIP $vm
    Write-Host "--------------------------------------------------------------------------------------------------------------------"
}
