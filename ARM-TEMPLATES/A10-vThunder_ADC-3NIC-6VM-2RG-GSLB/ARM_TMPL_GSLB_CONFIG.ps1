
# Get resource group name
param (
    [Parameter(Mandatory=$True)]
    [String] $resourceGroupName
)

# Check if resource group is present
if ($null -eq $resourceGroupName) {
    Write-Error "Resource Group name is missing" -ErrorAction Stop
}

#Connect to Azure portal
$status = $null
$status = Connect-AzAccount
if ($null -eq $status) {
    Write-Error "Authentication with Azure Portal Failed" -ErrorAction Stop
}

#ARM_TMPL_GSLB_PARAM.json contains parameters to get nic and vthunder names
$ParamData = Get-Content -Raw -Path .\ARM_TMPL_GSLB_PARAM.json | ConvertFrom-Json -AsHashtable
<#Add following parameters needed in the hash table
    "controllerlocation1"
    "site1location1"
    "site2location1"
    "nic1Name_controllerlocation1"
    "nic1Name_site1location1"
    "nic1Name_site2location1"
    "controllerlocation2"
    "site1location2"
    "site2location2"
    "nic1Name_controllerlocation2"
    "nic1Name_site1location2"
    "nic1Name_site2location2"
#>
$value = $ParamData.parameters.vmName.value+$ParamData.parameters.region1.value+"1"
$ParamData.parameters["controllerlocation1"] = @{value = $value}
$value = $ParamData.parameters.vmName.value+$ParamData.parameters.region1.value+"2"
$ParamData.parameters["site1location1"] = @{value = $value}
$value = $ParamData.parameters.vmName.value+$ParamData.parameters.region1.value+"3"
$ParamData.parameters["site2location1"] = @{value = $value}
$value = "mgmt"+$ParamData.parameters.region1.value+"1"
$ParamData.parameters["nic1Name_controllerlocation1"] = @{value = $value}
$value = "mgmt"+$ParamData.parameters.region1.value+"2"
$ParamData.parameters["nic1Name_site1location1"] = @{value = $value}
$value = "mgmt"+$ParamData.parameters.region1.value+"3"
$ParamData.parameters["nic1Name_site2location1"] = @{value = $value}

$value = $ParamData.parameters.vmName.value+$ParamData.parameters.region2.value+"1"
$ParamData.parameters["controllerlocation2"] = @{value = $value}
$value = $ParamData.parameters.vmName.value+$ParamData.parameters.region2.value+"2"
$ParamData.parameters["site1location2"] = @{value = $value}
$value = $ParamData.parameters.vmName.value+$ParamData.parameters.region2.value+"3"
$ParamData.parameters["site2location2"] = @{value = $value}
$value = "mgmt"+$ParamData.parameters.region2.value+"1"
$ParamData.parameters["nic1Name_controllerlocation2"] = @{value = $value}
$value = "mgmt"+$ParamData.parameters.region2.value+"2"
$ParamData.parameters["nic1Name_site1location2"] = @{value = $value}
$value = "mgmt"+$ParamData.parameters.region2.value+"3"
$ParamData.parameters["nic1Name_site2location2"] = @{value = $value}

#Write-Output $ParamData.parameters

#ARM_TMPL_GSLB_SLB_PARAM.json contains slb configurable parameters
$SLBParamData = Get-Content -Raw -Path .\ARM_TMPL_GSLB_SLB_PARAM.json | ConvertFrom-Json -AsHashtable

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
        $site
    )
    
    # AXAPI interface url headers
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    # initialize ethernet number to 1
    $ethernetNumber = 1
    $vmName = $ParamData.parameters.$site.value
    $vmInfo = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vmName
    Write-Host "Configuring vm: "$site
    $interfaces = $vmInfo.NetworkProfile.NetworkInterfaces.Id
    #Write-Host "interfaces" $interfaces

    # for each interface, get private ip address and add configuration in ethernet list
    foreach ($interface in $interfaces) {
        # AXAPI ethernets Url
        $Url = -join($BaseUrl, "/interface/ethernet/"+$ethernetNumber)
    
        # get interface private ip
        $interfaceName = $interface.Split('/')[-1]
        #Write-Host "interfacename": $interfaceName
        if ($interfaceName -match "mgmt*") {
            continue
        }

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
       
        # increse ethernet number by 1
        $ethernetNumber += 1
        }
}

function ConfigureServer {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to configure server
        AXAPI: /axapi/v3/slb/server
        .PARAMETER count
        count of the server
        .PARAMETER site
        site name
    #>
    param (
        $BaseUrl,
        $AuthorizationToken,
        $count,
        $site
    )
    # AXAPI Url
    $Url = -join($BaseUrl, "/slb/server")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")
    
    Write-Host "Configuring slb server for site:" $site

    $slbServerPortList = "slbServerPortList"+$count
    $slbServerHostOrDomain = "slbServerHostOrDomain"+$count
    $Ports = $SLBParamData.parameters.$slbServerPortList.value
    $servername = $SLBParamData.$slbServerHostOrDomain.servername
    $hostname =  $SLBParamData.$slbServerHostOrDomain.host
    $Body = @{
        "server"=@{}
    }
    $Body.server.add('name', $servername)
    $Body.server.add('host', $hostname)

    $Body.server.add('port-list', $Ports) 
    
    $Body = $Body | ConvertTo-Json -Depth 6


    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
    if ($null -eq $response) {
        Write-Error "Failed to configure slb server for site" 
    } else {
        Write-Host "Successfully Configured slb server for site:" $site
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
        .PARAMETER count
        count of the Service group
        .PARAMETER site
        site name
    #>
    param (
        $BaseUrl,
        $AuthorizationToken,
        $count,
        $site
    )
    $Url = -join($BaseUrl, "/slb/service-group")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    Write-Host "Configuring service group for site:" $site

    $serviceGroupList = "serviceGroupList"+$count
    $ServiceGroups = $SLBParamData.parameters.$serviceGroupList.value
    $Body = @{
        "service-group-list"= $ServiceGroups
    }
    $Body = $Body | ConvertTo-Json -Depth 6
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
    if ($null -eq $response) {
        Write-Error "Failed to configure service group for site"
    } else {
        Write-Host "Successfully Configured service group for site:" $site
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
        .PARAMETER count
        count of Virtual Server
        .PARAMETER site
        site name
        This function gets "name" from slb_param file and the ip address from $vmprivateip array
        $vmprivate ip contains the private ip addresses of the secondary interfaces of data1(client side) port of site devices
    #>
    param (
        $BaseUrl,
        $AuthorizationToken,
        $count,
        $site
    )
    $Url = -join($BaseUrl, "/slb/virtual-server")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    Write-Host "Configuring Virtual Server for site:" $site
    
    $virtualServerList = "virtualServerList"+$count
    $VirtualServerPorts = $SLBParamData.parameters.$virtualServerList.value

    $VirtualServer = @{
                "name" = $SLBParamData.parameters.$virtualServerList.'virtual-server-name'
                "ip-address" = $vmprivateip[$count-1]
    }
    $VirtualServer.Add("port-list", $VirtualServerPorts)
    $VirtualServerList = New-Object System.Collections.ArrayList
    [void]$VirtualServerList.Add($VirtualServer)
    $Body = @{}
    $Body.Add("virtual-server-list", $VirtualServerList)

    $Body = $Body | ConvertTo-Json -Depth 6

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
    if ($null -eq $response) {
        Write-Error "Failed to configure virtual server for site"
    } else {
        Write-Host "Successfully Configured virtual server for site:" $site
    }
}


function ConfigureServiceip {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to configure service ip
        AXAPI: /axapi/v3/gslb/service-ip
        .PARAMETER controller
        controller name
        This function configures service ip for controllers
        $vmpublicip will have the public ip addresses for secondary data interfaces-client side of site devices
        public ips will be configured as external-ips in the configuration on controllers
        $vmprivate ip contains the private ip addresses of the secondary data interfaces-client side of site devices
        These private ip addresses would be the virtual server ipaddresses on site devices
        The remaining values needed for configuring the service-ip are obtained from slb_param file
        example:
        gslb service-ip vs3 10.26.1.8
            external-ip 20.110.220.204
            port 80 tcp
    #>
    param (
        $BaseUrl,
        $AuthorizationToken,
        $controller
    )


    $Url = -join($BaseUrl, "/gslb/service-ip")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    for($i=0;$i -lt 4; $i++)
    {
        $serviceIpList_info = "serviceipList"+($i+1)
        $ServiceIpPorts = $SLBParamData.parameters.$serviceIpList_info.value
        $ServiceIp = @{
            "node-name" = $SLBParamData.parameters.$serviceIpList_info.'node-name'
            "ip-address"= $vmprivateip[$i]
            "external-ip" = $vmpublicip[$i]
        }
        $ServiceIp.Add("port-list", $ServiceIpPorts)
        $ServiceIpList = New-Object System.Collections.ArrayList
        [void]$ServiceIpList.Add($ServiceIp)
        $Body = @{}
        $Body.Add("service-ip-list", $ServiceIpList)
        $Body = $Body | ConvertTo-Json -Depth 6
        Write-Host $Body
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
        if ($null -eq $response) {
        Write-Error "Failed to configure ServiceIp for site" 
        } else {
        Write-Host "Successfully Configured ServiceIp for site:" $controller
        }
    }
}


function ConfigureSite {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to configure site
        AXAPI: /axapi/v3/gslb/site

        .PARAMETER controller
        controller name

        This function configures gslb sites on the controllers
        $mgmt_sites contains the management interfaces names of site devices
        #$vmmanagementpublicip will have the public ip addresses for the management interface of site devices
        the remaining information is obtained from the slb param file
        example:
        gslb site east_2
            geo-location "North America"
            slb-dev slb2 52.249.195.137
                vip-server vs2
    #>
    param (
        $BaseUrl,
        $AuthorizationToken,
        $controller
    )


    $Url = -join($BaseUrl, "/gslb/site")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    #getting the public ip addresses of the management interfaces of site devices
    #$vmmanagementpublicip will have the public ip addresses for the management interface of site devices

    $mgmt_sites = @($ParamData.parameters.nic1Name_site1location1.value, $ParamData.parameters.nic1Name_site2location1.value, $ParamData.parameters.nic1Name_site1location2.value, $ParamData.parameters.nic1Name_site2location2.value)
    $vmmanagementpublicip = New-Object System.Collections.ArrayList
    #Write-Host $vmname_sites
    foreach ($vm in $mgmt_sites) {
        $interfaceinfo = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $vm
        $publicipname  = $interfaceinfo.IpConfigurations.PublicIpAddress.Id.Split('/')[-1]
        $publicip = Get-AzPublicIpAddress -Name $publicipname -ResourceGroupName $resourceGroupName
        [void]$vmmanagementpublicip.Add($publicip.IpAddress)
    }

    for($i=0;$i -lt 4; $i++)
    {
        $siteList_info = "siteList"+($i+1)
        $vipname = @{
            "vip-name" = $SLBParamData.parameters.$siteList_info."vip-name"
        }
        $vipservernamelist = New-Object System.Collections.ArrayList
        [void]$vipservernamelist.Add($vipname)
        $vipserver = @{
	        "vip-server-name-list" = $vipservernamelist
        }
        $slbdev = @{
            "device-name" = $SLBParamData.parameters.$siteList_info."device-name"
            "ip-address" = $vmmanagementpublicip[$i]
            "vip-server" = $vipserver
        }
        
        $slbdevlist = New-Object System.Collections.ArrayList
        [void]$slbdevlist.Add($slbdev)

        $geolocation = @{
            "geo-location" = $SLBParamData.parameters.$siteList_info."geo-location"

        }
        $geolocationlist = New-Object System.Collections.ArrayList
        [void]$geolocationlist.Add($geolocation)

        $site = @{
            "site-name" = $SLBParamData.parameters.$siteList_info."site-name"
            "slb-dev-list" = $slbdevlist
            "multiple-geo-locations" = $geolocationlist
        }

        $sitelist = New-Object System.Collections.ArrayList
        [void]$sitelist.Add($site)

        $Body = @{}
        $Body.Add("site-list", $sitelist)
        $Body = $Body | ConvertTo-Json -Depth 9
        Write-Host $Body
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
        if ($null -eq $response) {
        Write-Error "Failed to configure site information"
        } else {
        Write-Host "Successfully Configured site information for :" $controller
        }
    }
}


function ConfigureSiteDevice {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to configure site device
        AXAPI: /axapi/v3/gslb/protocol/enable
        .PARAMETER site
        site name

        This function configures sites as gslb devices

        example:
        gslb protocol enable device

    #>
    param (
        $BaseUrl,
        $AuthorizationToken,
        $site
    )
    $Url = -join($BaseUrl, "/gslb/protocol/enable")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    Write-Host "Configuring device" $site "for gslb device" 
    
    $sitedevice = @{
        "type" = "device"
    }
    $sitelist = New-Object System.Collections.ArrayList
    [void]$sitelist.Add($sitedevice)
    
    $Body = @{
        "enable-list" = $sitelist
    }
    
    $Body = $Body | ConvertTo-Json -Depth 9

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
    if ($null -eq $response) {
        Write-Error "Failed to configure gslb site device"
    } else {
        Write-Host "Successfully Configured gslb site:" $site
    }
}

function ConfigureGslbPolicy {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to configure gslb policy
        AXAPI: /axapi/v3/gslb/policy

        .PARAMETER controller
        controller name

        This function configures gslb policy on controller devices
        example:
        gslb policy a10
        metric-order geographic
        dns server
    #>
    param (
        $BaseUrl,
        $AuthorizationToken,
        $controller
    )

    $Url = -join($BaseUrl, "/gslb/policy")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")


    $dns = @{
        "server" = 1
        "server-authoritative" = 1
    }
    $policy = @{
        "name" = $SLBParamData.parameters.dnsPolicy."policy-name"
        "metric-order" = 1
        "metric-type" = $SLBParamData.parameters.dnsPolicy."type"
        "dns" = $dns
    }
    $policylist = New-Object System.Collections.ArrayList
    [void]$policylist.Add($policy)
    
    $Body = @{}
    $Body.Add("policy-list", $policylist)
    
    $Body = $Body | ConvertTo-Json -Depth 9

        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
        if ($null -eq $response) {
        Write-Error "Failed to configure gslb policy" 
        } else {
        Write-Host "Successfully Configured gslb policy for :" $controller
        }
    }


    function ConfigureGslbZone {
        <#
            .PARAMETER BaseUrl
            Base url of AXAPI
            .PARAMETER AuthorizationToken
            AXAPI authorization token
            .DESCRIPTION
            Function to configure gslb zone
            AXAPI: /axapi/v3/gslb/zone
    
            .PARAMETER controller
            controller name

            This function configures gslb zone on controller
            The values are obtained from slb param file
            example:
            gslb zone gslb.a10.com
                policy a10
                service 80 www
                    dns-a-record vs1 static
                    dns-a-record vs2 static
                    dns-a-record vs3 static
                    dns-a-record vs4 static
        #>
        param (
            $BaseUrl,
            $AuthorizationToken,
            $controller
        )
    
        $Url = -join($BaseUrl, "/gslb/zone")
        $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
        $Headers.Add("Content-Type", "application/json")
    
    
        $dnsarecordsrv = @{
            "svrname" = $SLBParamData.parameters.serviceipList1."node-name"
            "static" = 1
        }
        $dnsarecordsrvlist = New-Object System.Collections.ArrayList
        [void]$dnsarecordsrvlist.Add($dnsarecordsrv)
        
        $dnsarecordsrv = @{
            "svrname" = $SLBParamData.parameters.serviceipList2."node-name"
            "static" = 1
        }
        $dnsarecordsrvlist.Add($dnsarecordsrv)
        
        $dnsarecordsrv = @{
            "svrname" = $SLBParamData.parameters.serviceipList3."node-name"
            "static" = 1
        }
        $dnsarecordsrvlist.Add($dnsarecordsrv)
        
        $dnsarecordsrv = @{
            "svrname" = $SLBParamData.parameters.serviceipList4."node-name"
            "static" = 1
        }
        
        $dnsarecordsrvlist.Add($dnsarecordsrv)
        
        $dnsarecord = @{
            "dns-a-record-srv-list" = $dnsarecordsrvlist
        }
        
        $service = @{
            "service-port" = $SLBParamData.parameters.gslbzone."service-port"
            "service-name" = $SLBParamData.parameters.gslbzone."service-name"
            "dns-a-record" = $dnsarecord
        }
        $servicelist = New-Object System.Collections.ArrayList
        [void]$servicelist.Add($service)
        
        $zone = @{
            "name" = $SLBParamData.parameters.gslbzone."name"
            "policy" = $SLBParamData.parameters.dnsPolicy."policy-name"
            "service-list" = $servicelist
        }
        $zonelist = New-Object System.Collections.ArrayList
        [void]$zonelist.Add($zone)
        
        $Body = @{}
        $Body.Add("zone-list", $zonelist)
        
        $Body = $Body | ConvertTo-Json -Depth 9
        Write-Host $Body
    
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
        if ($null -eq $response) {
            Write-Error "Failed to configure gslb policy" 
            } else {
            Write-Host "Successfully Configured gslb policy for :" $controller
            }
        }


    function ConfigureGslbServer {
        <#
            .PARAMETER BaseUrl
            Base url of AXAPI
            .PARAMETER AuthorizationToken
            AXAPI authorization token
            .DESCRIPTION
            Function to configure gslb server
            AXAPI: /axapi/v3/slb/virtual-server
            .PARAMETER count
            count of Virtual Server
            .PARAMETER controller
            site name

            This function configures gslb virtual server on the controllers
            example: 
            slb virtual-server vip-server 10.20.1.5
                port 53 udp
                    gslb-enable
        #>
        param (
            $BaseUrl,
            $AuthorizationToken,
            $count,
            $site
        )
        $Url = -join($BaseUrl, "/slb/virtual-server")
        $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
        $Headers.Add("Content-Type", "application/json")
    
        Write-Host "Configuring Gslb Server for controller:" $controller
        
        $GslbServerList = "gslbserverList"+$count
        $GslbServerPorts = $SLBParamData.parameters.$GslbServerList.value
    
        $GslbServer = @{
                    "name" = $SLBParamData.parameters.$GslbServerList.'virtual-server-name'
                    "ip-address"= $SLBParamData.parameters.$GslbServerList.'ip-address'
        }
        $GslbServer.Add("port-list", $GslbServerPorts)
        $GslbServerList = New-Object System.Collections.ArrayList
        [void]$GslbServerList.Add($GslbServer)
        $Body = @{}
        $Body.Add("virtual-server-list", $GslbServerList)
    
        $Body = $Body | ConvertTo-Json -Depth 6
        Write-Host "gslb server list" $Body
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
        if ($null -eq $response) {
            Write-Error "Failed to configure gslb server for controller"
        } else {
            Write-Host "Successfully Configured gslb server for controller:" $controller
        }
    }

    function ConfigureControllerandStatusInterval {
        <#
            .PARAMETER BaseUrl
            Base url of AXAPI
            .PARAMETER AuthorizationToken
            AXAPI authorization token
            .DESCRIPTION
            Function to configure controller and status interval
            AXAPI: /axapi/v3/gslb/protocol
            .PARAMETER controller
            site name

            This function configures status interval and enables controller function on controller devices

            example:
            gslb protocol status-interval 1
            gslb protocol enable controller
        #>
        param (
            $BaseUrl,
            $AuthorizationToken,
            $controller
        )
        $Url = -join($BaseUrl, "/gslb/protocol")
        $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
        $Headers.Add("Content-Type", "application/json")
    
        Write-Host "Configuring device" $controller "for controller and status interval" 
        
        $controller1 = @{
            "type" = "controller"
        }
        $controllerlist = New-Object System.Collections.ArrayList
        [void]$controllerlist.Add($controller1)
        $protocol = @{
            "enable-list" = $controllerlist
            "status-interval"= $SLBParamData.parameters.gslbprotocolStatus.'status-interval'
        }
        $Body = @{
            "protocol" = $protocol
        }
        
        $Body = $Body | ConvertTo-Json -Depth 9
        Write-Host "gslb server list" $Body
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
        if ($null -eq $response) {
            Write-Error "Failed to configure gslb controller"
        } else {
            Write-Host "Successfully Configured gslb controller and status interval:" $controller
        }
    }


    function ConfigureControllerGroup {
        <#
            .PARAMETER BaseUrl
            Base url of AXAPI
            .PARAMETER AuthorizationToken
            AXAPI authorization token
            .DESCRIPTION
            Function to configure gslb group
            AXAPI: /axapi/v3/gslb/group
            .PARAMETER count
            count of controller group
            .PARAMETER primaryip
            primary ip address- this is the ip addresses of the other controller device
            .PARAMETER controller 
            controller ip address
            .PARAMETER controllername
            controller name

            example:
            gslb group default
                enable
                primary 20.22.200.39
                priority 255
        #>
        param (
            $BaseUrl,
            $AuthorizationToken,
            $count,
            $primaryip,
            $controllerip,
            $controllername
        )
        $Url = -join($BaseUrl, "/gslb/group")
        $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
        $Headers.Add("Content-Type", "application/json")
    
        Write-Host "Configuring device" $controllername "for controller and status interval" 
        
        $primary = @{
            "primary" = $primaryip
        }
        $primarylist  = New-Object System.Collections.ArrayList
        [void]$primarylist.Add($primary)
        $gslbcontrollerGroup = "gslbcontrollerGroup"+$count
        $group = @{
            "name" = $SLBParamData.parameters.$gslbcontrollerGroup.'name'
            "priority" = $SLBParamData.parameters.$gslbcontrollerGroup.'priority'
            "primary-list" = $primarylist
            "enable" = 1
        }
        $grouplist  = New-Object System.Collections.ArrayList
        [void]$grouplist.Add($group)
        $Body = @{
            "group-list" = $grouplist
        }
        $Body = $Body | ConvertTo-Json -Depth 9
        Write-Host "gslb controller group" $Body
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
        if ($null -eq $response) {
            Write-Error "Failed to configure gslb controller group"
        } else {
            Write-Host "Successfully Configured gslb controller group:" $controllername
        }
    }


    function ConfigureDefaultRoute {
        <#
            .PARAMETER BaseUrl
            Base url of AXAPI
            .PARAMETER AuthorizationToken
            AXAPI authorization token
            .DESCRIPTION
            Function to configure default route
            AXAPI: /axapi/v3/ip/route/rib
            .PARAMETER ip
            next hop ipaddress
            .PARAMETER site
            name of the vthunder

            This function configures defualt route on all the devices(sites and controllers)
            This is needed for the traffic exiting the vthunder

            example:
            ip route 0.0.0.0 /0 10.20.1.1
        #>
        param (
            $BaseUrl,
            $AuthorizationToken,
            $ip,
            $site
        )
        $Url = -join($BaseUrl, "/ip/route/rib")
        $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
        $Headers.Add("Content-Type", "application/json")
    
        Write-Host "Configuring default route" 
        
        $ipnexthop = @{
            "ip-next-hop" = $ip
            "distance-nexthop-ip" = "1"
        }
        
        $ipnexthoplist = New-Object System.Collections.ArrayList
        [void]$ipnexthoplist.Add($ipnexthop)
        $rib = @{
            "ip-dest-addr" = "0.0.0.0"
            "ip-mask" = "/0"
            "ip-nexthop-ipv4" = $ipnexthoplist
        }
        $riblist = New-Object System.Collections.ArrayList
        [void]$riblist.Add($rib)
        
        $Body = @{
            "rib-list" = $riblist
        }
        
        $Body = $Body | ConvertTo-Json -Depth 9
  

        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
        if ($null -eq $response) {
            Write-Error "Failed to configure default route"
        } else {
            Write-Host "Successfully Configured default route" $site
        }
    }


    function EnableGeoLocation {
        <#
            .PARAMETER BaseUrl
            Base url of AXAPI
            .PARAMETER AuthorizationToken
            AXAPI authorization token
            .DESCRIPTION
            Function to enable geolocation
            AXAPI: /axapi/v3/system
            .PARAMETER site
            name of the VM

            This function enables geo location on controller devices

            example:

            no system geo-location load iana
            system geo-location load GeoLite2-Country
        #>
        param (
            $BaseUrl,
            $AuthorizationToken,
            $site
        )
        $Url = -join($BaseUrl, "/system")
        $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
        $Headers.Add("Content-Type", "application/json")
    
        Write-Host "Configuring Geolocation" 
        
        $geolocation = @{
            "geo-location-iana" = $SLBParamData.parameters.geolocation.'geo-location-iana'
            "geo-location-geolite2-city"= $SLBParamData.parameters.geolocation.'geo-location-geolite2-city'
            "geolite2-city-include-ipv6" = $SLBParamData.parameters.geolocation.'geolite2-city-include-ipv6'
            "geo-location-geolite2-country"= $SLBParamData.parameters.geolocation.'geo-location-geolite2-country'
            }
            $system = @{
            "geo-location" = $geolocation
            }
            $Body = @{
            "system" = $system
            }
   
        $Body = $Body | ConvertTo-Json -Depth 6
        Write-Host $Body

        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
        if ($null -eq $response) {
            Write-Error "Failed to configure geo location"
        } else {
            Write-Host "Successfully Configured geo location" $site
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
    

# public and private ip addresses of sites

#$vmname_sites contains the vthunder names of site devices
#$vmpublicip will have the public ip addresses for secondary data interfaces of site devices
#$vmprivateip will have the private ip addresses for secondary data interfaces of site devices

$vmname_sites = @($ParamData.parameters.site1location1.value, $ParamData.parameters.site2location1.value, $ParamData.parameters.site1location2.value, $ParamData.parameters.site2location2.value)
$vmpublicip = New-Object System.Collections.ArrayList
$vmprivateip = New-Object System.Collections.ArrayList
#Write-Host $vmname_sites
Write-Host "Gathering public and private ip addresses for site devices"
foreach ($vm in $vmname_sites) {
    $vmInfo = Get-AzVm -ResourceGroupName $resourceGroupName -Name $vm
    $interfaces = $vmInfo.NetworkProfile.NetworkInterfaces.Id
    $interfacename = $interfaces[-2].Split('/')[-1]
    $interfaceinfo = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $interfacename
    $publicipname  = $interfaceinfo.IpConfigurations.PublicIpAddress.Id.Split('/')[-1]
    $publicip = Get-AzPublicIpAddress -Name $publicipname -ResourceGroupName $resourceGroupName
    $privateip = $interfaceinfo.IpConfigurations.PrivateIpAddress[-1]
    [void]$vmpublicip.Add($publicip.IpAddress)
    [void]$vmprivateip.Add($privateip)
}

#management interface names of site devices
$site1MgmtNamelocation1 =$ParamData.parameters.nic1Name_site1location1.value
$site2MgmtNamelocation1 =$ParamData.parameters.nic1Name_site2location1.value
$site1MgmtNamelocation2 =$ParamData.parameters.nic1Name_site1location2.value
$site2MgmtNamelocation2 =$ParamData.parameters.nic1Name_site2location2.value

$sites_management = @($site1MgmtNamelocation1, $site2MgmtNamelocation1, $site1MgmtNamelocation2, $site2MgmtNamelocation2)

#vms will store the public ip addresses of the management interfaces of sites
$vms = New-Object System.Collections.ArrayList

foreach ($site_name in $sites_management)
{
    $response = Get-AzNetworkInterface -Name $site_name -ResourceGroupName $resourceGroupName
    $host1IPName = $response.IpConfigurations.PublicIpAddress.Id.Split('/')[-1]
    $response = Get-AzPublicIpAddress -Name $host1IPName -ResourceGroupName $resourceGroupName
    if ($null -eq $response) {
        Write-Error "Failed to get public ip" -ErrorAction Stop
    }    
    $hostIPAddress = $response.IpAddress
    [void]$vms.Add($hostIPAddress)
}

$index = 0
$count = 1
$vmNames = @("site1location1", "site2location1", "site1location2", "site2location2")

#configuration for site devices
foreach ($vm in $vms) {
   
    # Base URL of AXAPIs
    $vthunderBaseUrl = -join("https://", $vm, "/axapi/v3")

    
    $AuthorizationToken = Get-AuthToken -BaseUrl $vthunderBaseUrl

    ConfigureEthernets -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -site $vmNames[$index]

    ConfigureServer -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -count $count -site $vmNames[$index]

    ConfigureServiceGroup -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -count $count -site $vmNames[$index]

    ConfigureVirtualServer -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -count $count -site $vmNames[$index]
    
    ConfigureSiteDevice -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -site $vmNames[$index]

    #because sites in first region will have different next hop addresses with the sites in second region
    #we use the below if condition to pass next hop values to the function
    if($count -lt 3) {
        ConfigureDefaultRoute -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -ip $SLBParamData.parameters.defaultroute1.'next-hop' -site $vmNames[$index]
    } else {
        ConfigureDefaultRoute -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -ip $SLBParamData.parameters.defaultroute2.'next-hop' -site $vmNames[$index]
    }
  
    WriteMemory -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken

    $index += 1
    $count += 1

}

$controllerMgmtNamelocation1 =$ParamData.parameters.nic1Name_controllerlocation1.value
$controllerMgmtNamelocation2 =$ParamData.parameters.nic1Name_controllerlocation2.value

#management interface names of controller devices
$controller_management = @($controllerMgmtNamelocation1, $controllerMgmtNamelocation2)

#vms_controller will store the public ip addresses of the management interfaces of sites
$vms_controller = New-Object System.Collections.ArrayList
foreach ($controller_name in $controller_management)
{
    $response = Get-AzNetworkInterface -Name $controller_name -ResourceGroupName $resourceGroupName
    $hostIPName = $response.IpConfigurations.PublicIpAddress.Id.Split('/')[-1]
    $response = Get-AzPublicIpAddress -Name $hostIPName -ResourceGroupName $resourceGroupName
    if ($null -eq $response) {
        Write-Error "Failed to get public ip" -ErrorAction Stop
    }    
    $hostIPAddress = $response.IpAddress
    #Write-Host $hostIPAddress
    [void]$vms_controller.Add($hostIPAddress)
}

#Write-Host $vms_controller
$index = 0
$count = 1
$gslbgroupipaddress = 1
$vmNames = @("controllerlocation1", "controllerlocation2")

#configuration for controller devices
foreach ($vm_controller in $vms_controller) 
{
    
    $vthunderBaseUrl = -join("https://", $vm_controller, "/axapi/v3")
    $AuthorizationToken = Get-AuthToken -BaseUrl $vthunderBaseUrl

    ConfigureEthernets -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -site $vmNames[$index]
    ConfigureServiceip -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -controller $vm_controller
    ConfigureSite -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -controller $vm_controller
    ConfigureGslbPolicy -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -controller $vm_controller
    
    ConfigureGslbZone -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -controller $vm_controller
    
    ConfigureGslbServer -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -count $count -site $vmNames[$index]
    ConfigureControllerandStatusInterval -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken  -site $vmNames[$index]
  
    ConfigureControllerGroup -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -count $count -primary $vms_controller[$gslbgroupipaddress]  -controllerip $vm_controller -site $vmNames[$index]

    EnableGeoLocation -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -site $vmNames[$index]

    #because controller in first region will have different next hop address with the controller in second region
    #we use the below if condition to pass next hop values to the function
    if($count -lt 2) {
        ConfigureDefaultRoute -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -ip $SLBParamData.parameters.defaultroute1.'next-hop' -site $vmNames[$index]
    } else {
        ConfigureDefaultRoute -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -ip $SLBParamData.parameters.defaultroute2.'next-hop' -site $vmNames[$index]
    }

    WriteMemory -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken
    $index+=1
    $count+=1
    $gslbgroupipaddress-=1
    
}





