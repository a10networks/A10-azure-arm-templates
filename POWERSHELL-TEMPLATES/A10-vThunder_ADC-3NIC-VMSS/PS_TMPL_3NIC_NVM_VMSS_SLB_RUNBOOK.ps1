<#
.PARAMETER
    1.UpdateOnlyServers
	2.vThunderProcessedIP
.Description
    Script to configure a thunder instance as SLB.
Functions:
    1. Get-AuthToken
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
$slbParam = $slbParam | ConvertFrom-Json -AsHashtable

# Get variables
$resourceGroupName = $azureAutoScaleResources.resourceGroupName
Write-Output $resourceGroupName
# vthunder scale set
$vThunderScaleSetName = $azureAutoScaleResources.vThunderScaleSetName
Write-Output $vThunderScaleSetName
# servers scale set
$serverScaleSetName = $azureAutoScaleResources.serverScaleSetName
Write-Output $serverScaleSetName

$slbPorts = $slbParam.slb_port
$vipPorts = $slbParam.vip_port
$ribList = $slbParam.rib_list
Write-Output $slbPorts

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
        $ethernetCount
    )

    # AXAPI interface url headers
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

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
        $AuthorizationToken,
        $servers
    )

    # AXAPI Url
    $Url = -join($BaseUrl, "/slb/server")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    # get configured slb servers
    $slbResponse = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'GET' -Headers $Headers
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
        $Url = -join($BaseUrl, "/slb/server/", $server)
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'DELETE' -Headers $Headers
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
        $Body = @{
            "server"=$serverInfo
        }
        # convert body to json
        $Body = $Body | ConvertTo-Json -Depth 6
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
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
        $AuthorizationToken
    )
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    # get server list
    $slbUrl = -join($BaseUrl, "/slb/server")
    $slbResponse = Invoke-RestMethod -SkipCertificateCheck -Uri $slbUrl -Method 'GET' -Headers $Headers

    # get service group list
    $Url = -join($BaseUrl, "/slb/service-group")
    $sgResponse = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'GET' -Headers $Headers
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
                $Body = @{
                    "member"= $member
                }
                $Body = $Body | ConvertTo-Json -Depth 6
                $response = Invoke-RestMethod -SkipCertificateCheck -Uri $memberUrl -Method 'POST' -Headers $Headers -Body $Body

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
            $Body = @{
                "service-group"= $serviceGroup
            }
            $Body = $Body | ConvertTo-Json -Depth 6
            $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body

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
        $AuthorizationToken
    )
    $Url = -join($BaseUrl, "/slb/virtual-server")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
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


# get all server instances
$servers = GetServerInstances -resourceGroupName $resourceGroupName -vmssName $serverScaleSetName

# Base URL of AXAPIs
$vthunderBaseUrl = -join("https://", $vThunderProcessingIP, "/axapi/v3")

# Invoke Get-AuthToken
$AuthorizationToken = Get-AuthToken -BaseUrl $vthunderBaseUrl

if ($UpdateOnlyServers -eq $true){
	# Invoke ConfigureServer
	ConfigureServer -AuthorizationToken $AuthorizationToken -BaseUrl $vthunderBaseUrl -servers $servers

	# Invoke ConfigureServiceGroup
	ConfigureServiceGroup -AuthorizationToken $AuthorizationToken -BaseUrl $vthunderBaseUrl

	# Invoke WriteMemory
	WriteMemory -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken

	Write-Output "Updated server information"
}
else{
	# Invoke Configure Ethernets for all new vthunders
	ConfigureEthernets -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -ethernetCount $ethernetCount

	# Invoke IPRouteConfig for adding ip route
	IPRouteConfig -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken

	# Invoke ConfigureServer
	ConfigureServer -AuthorizationToken $AuthorizationToken -BaseUrl $vthunderBaseUrl -servers $servers

	# Invoke ConfigureServiceGroup
	ConfigureServiceGroup -AuthorizationToken $AuthorizationToken -BaseUrl $vthunderBaseUrl

	# Invoke ConfigureVirtualServer
	ConfigureVirtualServer -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken

	# Invoke WriteMemory
	WriteMemory -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken

	Write-Output "SLB-Config Done"
}
