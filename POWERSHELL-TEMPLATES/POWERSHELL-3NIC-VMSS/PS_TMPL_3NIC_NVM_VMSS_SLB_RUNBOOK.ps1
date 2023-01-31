<#
.PARAMETER
    1.UpdateOnlyServers
	2.vThunderProcessingIP
.Description
    Script to configure a thunder instance as SLB.
Functions:
    1. GetAuthToken
    2. ConfigureEth1
    3. ConfigureServerS1
    4. ConfigureServiceGroup
    5. ConfigureVirtualServer
    6. WriteMemory
#>
param (
    [Parameter(Mandatory=$True)]
    [Boolean] $UpdateOnlyServers,
    [Parameter(Mandatory=$True)]
    [String] $vThunderProcessingIP
)

$azureAutoScaleResources = Get-AutomationVariable -Name azureAutoScaleResources
$azureAutoScaleResources = $azureAutoScaleResources | ConvertFrom-Json
$vThUserName = Get-AutomationVariable -Name vThUserName
$vThPassword = Get-AutomationVariable -Name vThCurrentPassword
$oldPassword = Get-AutomationVariable -Name vThDefaultPassword

if ($null -eq $azureAutoScaleResources) {
    Write-Error "azureAutoScaleResources data is missing." -ErrorAction Stop
}

# Authenticate with Azure Portal
$appId = $azureAutoScaleResources.appId
$secret = Get-AutomationVariable -Name clientSecret
$tenantId = $azureAutoScaleResources.tenantId

$secureStringPwd = $secret | ConvertTo-SecureString -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appId, $secureStringPwd
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId

# Get ports from variables
$slbParam = Get-AutomationVariable -Name slbParam
$slbParam = $slbParam | ConvertFrom-Json

# Get variables
$resourceGroupName = $azureAutoScaleResources.resourceGroupName
# vthunder scale set
$vThunderScaleSetName = $azureAutoScaleResources.vThunderScaleSetName
# servers scale set
$serverScaleSetName = $azureAutoScaleResources.serverScaleSetName

$slbPorts = $slbParam.slb_port
$vipPorts = $slbParam.vip_port
$ribList = $slbParam.rib_list


$ethernetCount = 2

function GetServerInstances {
    <#
    .DESCRIPTION
    function to get ip address of new instance added in VMSS
    #>
    param (
        $resourceGroupName,
        $vmssName
    )
    # client and private ip mapping
    $clients = @{}

    # get vms present in vmss
    $vms = Get-AzVmssVM -ResourceGroupName $resourceGroupName -VMScaleSetName $vmssName

    # Get private ip address of each vm
    foreach($vm in $vms){
        # get interface and check private ip address
        $interfaceId = $vm.NetworkProfile.NetworkInterfaces[0].Id
        $interfaceName = $interfaceId.Split('/')[-1]
        $interfaceConfig = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $interfaceName -VirtualMachineScaleSetName $vmssName -VirtualMachineIndex $vm.InstanceId
        $vmPrivateIp = $interfaceConfig.IpConfigurations[0].PrivateIpAddress

        # add client name and private mapping in hashtable
        $clients.Add($vm.Name, $vmPrivateIp)
    }

    return $clients
}

function GetAuthToken {
    <#
        .PARAMETER base_url
        Base url of AXAPI
        .DESCRIPTION
        Function to get Authorization token from axapi
        AXAPI: /axapi/v3/auth
    #>
    param (
        $baseUrl,
        $vThPass
    )

    # AXAPI Auth url
    $url = -join($baseUrl, "/auth")
    # AXAPI header
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    # AXAPI Auth url json body
    $body = "{
    `n    `"credentials`": {
    `n        `"username`": `"$vThUserName`",
    `n        `"password`": `"$vThPass`"
    `n    }
    `n}"
    $maxRetry = 5
    $currentRetry = 0
    while ($currentRetry -ne $maxRetry) {
        # Invoke Auth url
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $response = Invoke-RestMethod -Uri $url -Method 'POST' -Headers $headers -Body $body
        # fetch Authorization token from response
        $authorizationToken = $response.authresponse.signature
        if ($null -eq $authorizationToken) {
            Write-Error "Retry $currentRetry to get authorization token"
            $currentRetry++
            start-sleep -s 60
        } else {
            break
        }
    }
    if ($null -eq $authorizationToken) {
            Write-Error "Falied to get authorization token from AXAPI" -ErrorAction Stop
    }
    return $authorizationToken
}

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
        $authorizationToken,
        $ethernetCount
    )

    # initialize ethernet number to 1
    $ethernetNumber = 1

    # for each interface configuration in ethernet
    for ($ethernetNumber; $ethernetNumber -le $ethernetCount; $ethernetNumber++) {
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
        # AXAPI interface url headers
        $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $Headers.Add("Authorization", -join("A10 ", $authorizationToken))
        $Headers.Add("Content-Type", "application/json")
        $body = $body | ConvertTo-Json -Depth 6
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        # Invoke interface AXAPI
        $response = Invoke-RestMethod -Uri $Url -Method 'POST' -Headers $Headers -Body $body
        if ($null -eq $response) {
            Write-Error "Failed to configure ethernet-"$ethernetNumber" ip"
        } else {
            Write-Host "configured ethernet-"$ethernetNumber" ip"
        }

    }
}

function IPRouteConfig {
    param (
        $BaseUrl,
        $authorizationToken
    )
    # AXAPI Url
    $Url = -join($BaseUrl, "/ip/route/rib")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $Headers.Add("Content-Type", "application/json")

    # payload for AXAPI
    $body = @{
        "rib-list" = $ribList
    }

    # convert into json format
    $body = $body | ConvertTo-Json -Depth 6
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-RestMethod -Uri $Url -Method 'POST' -Headers $Headers -Body $body
    if ($null -eq $response) {
        Write-Error "Failed to configure ip route"
    } else {
        Write-Host "Configured ip route"
    }
}

# add new instaces ip in vthunder SLB configuration
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
        $BaseUrl,
        $authorizationToken,
        $servers
    )

    # AXAPI Url
    $Url = -join($BaseUrl, "/slb/server")
    
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $Headers.Add("Content-Type", "application/json")

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    # get configured slb servers
    $slbResponse = Invoke-RestMethod -Uri $Url -Method 'GET' -Headers $Headers
    
    # get server list
    $serverList = $slbResponse.'server-list'
    $serverSet = New-Object System.Collections.Generic.HashSet[String]

    # add servers in server set
    foreach ($server in $serverList){
        $serverSet.Add($server.name)
    }

    # remove deleted servers from slb configuration
    foreach ($server in $serverSet){
        # check if configured server exists
        if ($servers.Contains($server)){
            continue
        }
        # AXAPI Url
        $Headers1 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $Headers1.Add("Authorization", -join("A10 ", $authorizationToken))
        $Headers1.Add("Content-Type", "application/json")
        $Url = -join($BaseUrl, "/slb/server/", $server)
        
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $response = Invoke-RestMethod -Uri $Url -Method 'DELETE' -Headers $Headers1
        if ($null -eq $response) {
            Write-Error "Failed to delete server $server"
        } else {
            Write-Host "Deleted server $server"
            $serverSet.Remove($server)
        }
    }

    # AXAPI Url
    $Url = -join($BaseUrl, "/slb/server")
    # add new servers in slb configuration
    foreach ($server in $servers.Keys){
        # check if server already configured
        if ($serverSet.Contains($server)){
            continue
        }
        $serverInfo = @{
            "name" = $server
            "host" = $servers[$server]
            "port-list" = $slbPorts.value
        }
        # AXAPI payload
        $body = @{
            "server"=$serverInfo
        }
        # convert body to json
        $body = $body | ConvertTo-Json -Depth 6
        $Headers2 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $Headers2.Add("Authorization", -join("A10 ", $authorizationToken))
        $Headers2.Add("Content-Type", "application/json")
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $response = Invoke-RestMethod -Uri $Url -Method 'POST' -Headers $Headers2 -Body $body
        if ($null -eq $response) {
            Write-Error "Failed to configure server $server"
        } else {
            Write-Host "Configured server $server"
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
        $authorizationToken
    )
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $Headers.Add("Content-Type", "application/json")

    # get server list
    $slbUrl = -join($BaseUrl, "/slb/server")
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $slbResponse = Invoke-RestMethod -Uri $slbUrl -Method 'GET' -Headers $Headers

    # get service group list
    $Headers1 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers1.Add("Authorization", -join("A10 ", $authorizationToken))
    $Headers1.Add("Content-Type", "application/json")
    $Url = -join($BaseUrl, "/slb/service-group")
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $sgResponse = Invoke-RestMethod -Uri $Url -Method 'GET' -Headers $Headers1
    $sgList = $sgResponse.'service-group-list'

    # Create existing service group and members mapping
    $sgMemberMap = New-Object System.Collections.Hashtable
    foreach ($sg in $sgList) {
        $memberSet = New-Object System.Collections.Generic.HashSet[String]
        $memberList = $sg.'member-list'
        foreach ($member in $memberList){
            $memberSet.Add($member.name)
        }
        $sgMemberMap.Add($sg.name, $memberSet)
    }

    # Add server in service groups, if service group does not exist then create and add server
    # get server list
    $serverList = $slbResponse.'server-list'

    # check for each port service group exists or not
    # create service group if does not exist then add server
    foreach ($port in $slbPorts.value){
        # check if service group exist
        $sgName = "sg"+$port.'port-number'
        if ($sgMemberMap.Contains($sgName)){
            # AXAPI for adding member
            $memberUrl = -join($BaseUrl, "/slb/service-group/",$sgName,"/member")
            # Add each member in service group
            foreach ($server in $serverList) {
                # check if server member already exist in service group
                if ($sgMemberMap.$sgName.Contains($server.name)){
                    continue
                }
                # add port in member
                $member = @{
                    "name" = $server.name
                    "port" = $port.'port-number'
                }
                # AXAPI payload
                $body = @{
                    "member"= $member
                }
                $body = $body | ConvertTo-Json -Depth 6
                $Headers3 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                $Headers3.Add("Authorization", -join("A10 ", $authorizationToken))
                $Headers3.Add("Content-Type", "application/json")
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
                $response = Invoke-RestMethod -Uri $memberUrl -Method 'POST' -Headers $Headers3 -Body $body

                $memberName = $member.name
                if ($null -eq $response) {
                    Write-Error "Failed to add member $memberName in service group $sgName"
                } else {
                    Write-Host "Added member $memberName in service group $sgName"
                }
            }
        } else {
            # create member list array
            $memberList = New-Object System.Collections.ArrayList

            # create service group
            $serviceGroup = @{
                "name" = "sg"+$port.'port-number'
                "protocol" = $port.protocol
                "health-check-disable" = 1
            }
            # Add each member in service group
            foreach ($server in $serverList) {
                # add port in member
                $member = @{
                    "name" = $server.name
                    "port" = $port.'port-number'
                }
                # add member in member list
                $memberList.Add($member)
            }
            # add member list in service group
            $serviceGroup.Add("member-list", $memberList)
            # AXAPI payload
            $body = @{
                "service-group"= $serviceGroup
            }
            $body = $body | ConvertTo-Json -Depth 6
            $Headers4 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $Headers4.Add("Authorization", -join("A10 ", $authorizationToken))
            $Headers4.Add("Content-Type", "application/json")
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
            $response = Invoke-RestMethod -Uri $Url -Method 'POST' -Headers $Headers4 -Body $body

            $name = $serviceGroup.name
            if ($null -eq $response) {
                Write-Error "Failed to configure service group $name"
            } else {
                Write-Host "Configured service group $name"
            }
        }
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
        $authorizationToken
    )
    $Url = -join($BaseUrl, "/slb/virtual-server")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $Headers.Add("Content-Type", "application/json")

    $VirtualServerPorts = $vipPorts.value

    $VirtualServer = @{
                "name" = "vip"
                "use-if-ip" = 1
                "ethernet" = 1
    }
    $VirtualServer.Add("port-list", $VirtualServerPorts)
    $VirtualServerList = New-Object System.Collections.ArrayList
    $VirtualServerList.Add($VirtualServer)
    $body = @{}
    $body.Add("virtual-server-list", $VirtualServerList)

    $body = $body | ConvertTo-Json -Depth 6
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-RestMethod -Uri $Url -Method 'POST' -Headers $Headers -Body $body
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
    $Url = -join($BaseUrl, "/write/memory")

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Authorization", -join("A10 ", $AuthorizationToken))

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-RestMethod -Uri $Url -Method 'POST' -Headers $headers

}

# get all server instances
$servers = GetServerInstances -resourceGroupName $resourceGroupName -vmssName $serverScaleSetName

# Base URL of AXAPIs
$vthunderBaseUrl = -join("https://", $vThunderProcessingIP, "/axapi/v3")

# Invoke GetAuthToken
$authorizationToken = GetAuthToken -baseUrl $vthunderBaseUrl -vThPass $vThPassword

if ($authorizationToken -eq 401){
    $authorizationToken = GetAuthToken -baseUrl $vthunderBaseUrl -vThPass $oldPassword
}

if ($UpdateOnlyServers -eq $true){
	# Invoke ConfigureServer
	ConfigureServer -AuthorizationToken $authorizationToken -BaseUrl $vthunderBaseUrl -servers $servers

	# Invoke ConfigureServiceGroup
	ConfigureServiceGroup -AuthorizationToken $authorizationToken -BaseUrl $vthunderBaseUrl

	# Invoke WriteMemory
	WriteMemory -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken

	Write-Output "Updated server information"
}
else{
	# Invoke Configure Ethernets for all new vthunders
	ConfigureEthernets -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken -ethernetCount $ethernetCount

	# Invoke IPRouteConfig for adding ip route
	IPRouteConfig -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken

	# Invoke ConfigureServer
	ConfigureServer -AuthorizationToken $authorizationToken -BaseUrl $vthunderBaseUrl -servers $servers

	# Invoke ConfigureServiceGroup
	ConfigureServiceGroup -AuthorizationToken $authorizationToken -BaseUrl $vthunderBaseUrl

	# Invoke ConfigureVirtualServer
	ConfigureVirtualServer -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken

	# Invoke WriteMemory
	WriteMemory -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken

	Write-Output "SLB-Config Done"
}
