# Authenticate with Azure Portal
$appId = Get-AutomationVariable -Name appId
$secret = Get-AutomationVariable -Name clientSecret
$tenantId = Get-AutomationVariable -Name tenantId
$vThUsername = Get-AutomationVariable -Name vThUsername
$vThPassword = Get-AutomationVariable -Name vThPassword

try {
    $SecureStringPwd = $secret | ConvertTo-SecureString -AsPlainText -Force
    $pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appId, $SecureStringPwd
    Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId -ErrorAction Stop
    Write-Output "Authenticated with Auzre portal using service app"   
}
catch {
    Write-Output "Authentication Failed with Auzre portal using service app"
    Write-Error $_
}

try {
    # Get ports from variables
    $slbPorts = Get-AutomationVariable -Name portList -ErrorAction Stop
    $slbPorts = $slbPorts | ConvertFrom-Json -AsHashtable
    Write-Host $slbPorts.value
}
catch{
    Write-Output "Failed to get portList variable from Automation Account"
    Write-Error $_
}
try {
    # Get variables
    $resourceGroupName = Get-AutomationVariable -Name resourceGroupName -ErrorAction Stop
}
catch {
    Write-Output "Failed to get resourceGroupName variable from Automation Account"
    Write-Error $_
}
try {
    # Get vThunder-1 management interface name
    $mgmtInterface1 = Get-AutomationVariable -Name mgmtInterface1 -ErrorAction Stop
}
catch {
    Write-Output "Failed to get mgmtInterface1 variable from Automation Account"
    Write-Error $_
}
try {
    # Get vThunder-2 management interface name
    $mgmtInterface2 = Get-AutomationVariable -Name mgmtInterface2 -ErrorAction Stop
}
catch {
    Write-Output "Failed to get mgmtInterface2 variable from Automation Account"
    Write-Error $_
}
try{
    # get vmss name
    $vmssName = Get-AutomationVariable -Name vmssName -ErrorAction Stop
}
catch {
    Write-Output "Failed to get variable vmssName from Automation Account" 
    Write-Error $_
}

# get vthunders public ip address
function GetvThunderIpAdd {
    <#
        .DESCRIPTION
        function to get management public ip address
    #>
    param (
        $resourceGroupName,
        $mgmtInterface
    )
    # Get vThunder1 IP Address
    $response = Get-AzNetworkInterface -Name $mgmtInterface -ResourceGroupName $resourceGroupName
    $hostIPName = $response.IpConfigurations.PublicIpAddress.Id.Split('/')[-1]
    
    
    try {
        $response = Get-AzPublicIpAddress -Name $hostIPName -ResourceGroupName $resourceGroupName -ErrorAction Stop    
        $hostIPAddress = $response.IpAddress
        return $hostIPAddress
    }
    catch {
        Write-Output "Failed to get public ip"
        Write-Error $_ -ErrorAction Stop
    }
}

function GetNewInstance {
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
    `n        `"username`": `"$vThUsername`",
    `n        `"password`": `"$vThPassword`"
    `n    }
    `n}"
    try {
        # Invoke Auth url
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $headers -Body $body -ErrorAction Stop
        # fetch Authorization token from response
        $AuthorizationToken = $Response.authresponse.signature
        return $AuthorizationToken
    }
    catch {
        Write-Output "Falied to get authorization token from AXAPI"
        Write-Error $_ -ErrorAction Stop
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
        try {
            Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'DELETE' -Headers $Headers -ErrorAction Stop
            Write-Output "Deleted server $server"
            $serverSet.Remove($server)
        }
        catch {
            Write-Output "Failed to delete server $server"
            Write-Error $_
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
        try {
            Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body -ErrorAction Stop
            Write-Output "Configured server $server"
        }
        catch {
            Write-Output "Failed to configure server $server"
            Write-Error $_
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

    # Add server is service groups, if service group does not exist then create and add server
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
                $memberName = $member.name  
                try {
                    Invoke-RestMethod -SkipCertificateCheck -Uri $memberUrl -Method 'POST' -Headers $Headers -Body $Body -ErrorAction Stop
                    Write-Output "Added member $memberName in service group $sgName" 
                }
                catch {
                    Write-Output "Failed to add member $memberName in service group $sgName"
                    Write-Error $_
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
            $name = $serviceGroup.name
            try {
                Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body -ErrorAction Stop
                Write-Output "Configured service group $name"
            }
            catch {
                Write-Output "Failed to configure service group $name"
                Write-Error $_
            }
        }
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
        Write-Output "Failed to get partition name" 
        Write-Error "Failed to get partition name"
    } else {
        $Url = -join($BaseUrl, "/write/memory")
        $Headers.Add("Content-Type", "application/json")

        $Body = "{
        `n  `"memory`": {
        `n    `"partition`": `"$partition`"
        `n  }
        `n}"
        
        try {
            $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body -ErrorAction Stop
            Write-Output "Configurations are saved on partition: "$partition
        }
        catch {
            Write-Output "Failed to run write memory command"
            Write-Error $_
        }
    }
}


# wait for 30 seconds to get updated data
start-sleep -s 30

# get all server instances
$servers = GetNewInstance -resourceGroupName $resourceGroupName -vmssName $vmssName

# execute functions
$mgmtInterfaces = ($mgmtInterface1, $mgmtInterface2)
foreach ($interface in $mgmtInterfaces) {
    # get vThunder ip address
    $hostIPAddress = GetvThunderIpAdd -resourceGroupName $resourceGroupName -mgmtInterface $interface
    Write-Output "Configuring vThunder $hostIPAddress" 
   
    # Base URL of AXAPIs
    $vthunderBaseUrl = -join("https://", $hostIPAddress, "/axapi/v3")
    
    # Invoke Get-AuthToken
    $AuthorizationToken = Get-AuthToken -BaseUrl $vthunderBaseUrl
    Write-Output "Fetched authentication token."

    # Invoke ConfigureServer
    ConfigureServer -AuthorizationToken $AuthorizationToken -BaseUrl $vthunderBaseUrl -servers $servers 
    Write-Output "Configured servers"

    # Invoke ConfigureServiceGroup
    ConfigureServiceGroup -AuthorizationToken $AuthorizationToken -BaseUrl $vthunderBaseUrl
    Write-Output "Configured service-group"

    # Invoke WriteMemory
    WriteMemory -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken
    Write-Output "saved running configuration"
}
