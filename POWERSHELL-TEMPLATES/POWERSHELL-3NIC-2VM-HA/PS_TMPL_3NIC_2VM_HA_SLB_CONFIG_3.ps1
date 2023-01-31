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

# Connect to Azure portal
$status = $null
$status = Connect-AzAccount
if ($null -eq $status) {
    Write-Error "Authentication with Azure Portal Failed" -ErrorAction Stop
}

# Get PS_TMPL_3NIC_2VM_HA_PARAM parameter file content
$ParamData = Get-Content -Raw -Path PS_TMPL_3NIC_2VM_HA_PARAM.json | ConvertFrom-Json -AsHashtable
if ($null -eq $ParamData) {
    Write-Error "PS_TMPL_3NIC_2VM_HA_PARAM.json file is missing." -ErrorAction Stop
}

# Get PS_TMPL_3NIC_2VM_HA_SLB_CONFIG_PARAM slb parameter file content
$SLBParamData = Get-Content -Raw -Path PS_TMPL_3NIC_2VM_HA_SLB_CONFIG_PARAM.json | ConvertFrom-Json -AsHashtable
if ($null -eq $SLBParamData) {
    Write-Error "PS_TMPL_3NIC_2VM_HA_SLB_CONFIG_PARAM.json file is missing." -ErrorAction Stop
}
$resourceGroupName = $SLBParamData.parameters.resourceGroupName
$vThUsername = $SLBParamData.parameters.vThUsername
$vThNewPasswordVal = Read-Host "Enter Password" -AsSecureString
$vThNewPassword = ConvertFrom-SecureString -SecureString $vThNewPasswordVal -AsPlainText


# Get user input to apply ssl certificate.
$title    = 'SSL Certificate'
$question = 'Do you want to upload ssl certificate ?'

$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 0) {
    $uploadSSLCert = $true
} else {
    $uploadSSLCert = $false
}

# Get request timeout
$Timeout = $SLBParamData.parameters.sslConfig.requestTimeOut

if ($uploadSSLCert)
    {
        $Path = $SLBParamData.parameters.sslConfig.Path
        if ($null -eq $Path) {
                Write-Error "Please provide the certificate file path" -ErrorAction Stop
            }
        $isExist = Test-Path -Path $Path -PathType Leaf
        if ($False -eq $isExist){
            Write-Error "Certificate file is not present on given path" -ErrorAction Stop
        }

        $File = $SLBParamData.parameters.sslConfig.File
        if ($null -eq $File) {
                Write-Error "Please provide the certificate file name" -ErrorAction Stop
            }
        $CertificationType = $SLBParamData.parameters.sslConfig.CertificationType
        if ($null -eq $CertificationType) {
                Write-Error "Please provide the certificate type" -ErrorAction Stop
            }
    }

# Get arguments from parameter file
$host1MgmtName = $ParamData.parameters.nic1Name_vm1.value
$host2MgmtName = $ParamData.parameters.nic1Name_vm2.value
# get arguments from slb paramter file
$slbServerHostOrDomain = $SLBParamData.parameters.slbServerHostOrDomain
$virtualServer = $SLBParamData.parameters.virtualServerList

# Print variables
if ($null -ne $slbServerHostOrDomain.host) {
    Write-Host "SLB Server Host IP: " $slbServerHostOrDomain.host
}
elseif ($null -ne $slbServerHostOrDomain.'fqdn-name') {
    Write-Host "SLB Server Domain: " $slbServerHostOrDomain.'fqdn-name'
}
Write-Host "Virtual Server Name: " $virtualServer.'virtual-server-name'
Write-Host "Resource Group Name: " $resourceGroupName

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
    `n        `"username`": `"$vThUsername`",
    `n        `"password`": `"$vThNewPassword`"
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
    $vmName = $ParamData.parameters.$vmName.value
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
        $BaseUrl,
        $AuthorizationToken
    )
    # AXAPI Url
    $Url = -join($BaseUrl, "/slb/server")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    $Ports = $SLBParamData.parameters.slbServerPortList.value

    $Body = @{
        "server"=@{}
    }
    $Body.server.add('name', $slbServerHostOrDomain.'server-name')
    if ($null -ne $slbServerHostOrDomain.host) {
        $Body.server.add('host', $slbServerHostOrDomain.host)
    }
    elseif ($null -ne $slbServerHostOrDomain.'fqdn-name') {
        $Body.server.add('fqdn-name', $slbServerHostOrDomain.'fqdn-name')
    }
    else {
        Write-Error "host or fqdn-name is required in slb_parameter file"
    }
    $Body.server.add('port-list', $Ports)

    $Body = $Body | ConvertTo-Json -Depth 6

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
    if ($null -eq $response) {
        Write-Error "Failed to configure server"
    } else {
        Write-Host "Configured server"
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

function SSLUpload {
	    <#
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to configure service group
        AXAPI: /file/ssl-cert
    #>
    param (
        $BaseUrl,
        $AuthorizationToken
    )

    $Url = "$BaseUrl/file/ssl-cert"
	$boundary = "----WebKitFormBoundary2f4l91ArINVV3IAK"


	$fileBytes = [System.IO.File]::ReadAllBytes($Path);
    $fileEnc = [System.Text.Encoding]::GetEncoding('ISO-8859-1').GetString($fileBytes);

	$LF = "`r`n";

	$Headers = @{
		 Authorization = "A10 $AuthorizationToken"
		"Content-Type" = "multipart/form-data; boundary=$boundary"
    }

	$bodyLines = (
		"--$boundary",
		"Content-Disposition: form-data; name=`"json`"; filename=`"blob`"",
		"Content-Type: application/json",
		"",
		"{`"ssl-cert`": {`"file`": `"$File`", `"action`": `"import`", `"file-handle`": `"$File.$CertificationType`", `"certificate-type`": `"$CertificationType`"}}",
		"--$boundary",
		"Content-Disposition: form-data; name=`"file`"; filename=`"$File.$CertificationType`"",
		"Content-Type: application/octet-stream",
		"",
		$fileEnc,
		"--$boundary--$LF"
	) -join $LF

	$params = @{
        Uri         = $Url
        Body        = $bodyLines
        Method      = 'Post'
		Headers     = $Headers
    }
    $response = Invoke-RestMethod @params -AllowUnencryptedAuthentication:$true -SkipCertificateCheck:$true -SkipHeaderValidation:$false -SkipHttpErrorCheck:$false -DisableKeepAlive:$false -TimeoutSec $Timeout
    if ($null -eq $response) {
        Write-Error "Failed to configure SSL certificate"
    } else {
        Write-Host "SSL Configured."
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
$vms = @($host1IPAddress, $host2IPAddress)
$vmNames = @("vmName_vthunder1", "vmName_vthunder2")
foreach ($vm in $vms) {
    # Base URL of AXAPIs
    $vthunderBaseUrl = -join("https://", $vm, "/axapi/v3")
    # Call above functions
    # Invoke Get-AuthToken
    $AuthorizationToken = Get-AuthToken -BaseUrl $vthunderBaseUrl
    # Invoke Configure Ethernets for both VMs
    ConfigureEthernets -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken -vmName $vmNames[$index]
    # Invoke CreateServer
    ConfigureServer -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken
    # Invoke ConfigureServiceGroup
    ConfigureServiceGroup -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken
    # Invoke ConfigureVirtualServer
    ConfigureVirtualServer -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken
    if ($uploadSSLCert){
        SSLUpload -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken
    }
    # Invoke WriteMemory
    WriteMemory -BaseUrl $vthunderBaseUrl -AuthorizationToken $AuthorizationToken
    # increment index
    $index += 1
    Write-Host "Configured vThunder Instance "$index
}
