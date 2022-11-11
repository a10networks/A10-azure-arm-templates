<#
.PARAMETER resource group
Name of resource group
.EXAMPLE
To run script execute .\<name-of-script> <resource-group-name>
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

# Get resource group name
param (
    [Parameter(Mandatory=$True)]
    [String] $resourceGroupName
)

Write-Host "Executing 2NIC-SLB-Configuration"

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

# Get ARM_TMPL_2NIC_1VM_PARAM.json file content
$ParamData = Get-Content -Raw -Path ARM_TMPL_2NIC_1VM_PARAM.json | ConvertFrom-Json -AsHashtable
if ($null -eq $ParamData) {
    Write-Error "ARM_TMPL_2NIC_1VM_PARAM.json file is missing." -ErrorAction Stop
}

# Get ARM_TMPL_2NIC_1VM_SLB_CONFIG_PARAM.json file content
$SLBParamData = Get-Content -Raw -Path ARM_TMPL_2NIC_1VM_SLB_CONFIG_PARAM.json | ConvertFrom-Json -AsHashtable
if ($null -eq $SLBParamData) {
    Write-Error "ARM_TMPL_2NIC_1VM_SLB_CONFIG_PARAM.json file is missing." -ErrorAction Stop
}

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

# Get arguments
$hostIPName = $ParamData.parameters.publicIPAddressName.value
$ethPrivateIPAddress = $ParamData.parameters.eth1PrivateAddress.value

$slbServerHostOrDomain = $SLBParamData.parameters.slbServerHostOrDomain
$virtualServer = $SLBParamData.parameters.virtualServerList

# Print variables
Write-Host "Public IP Name: " $hostIPName
Write-Host "Ethernet-1 Private IP: " $ethPrivateIPAddress
if ($null -ne $slbServerHostOrDomain.host) {
    Write-Host "SLB Server Host IP: " $slbServerHostOrDomain.host
}
elseif ($null -ne $slbServerHostOrDomain.'fqdn-name') {
    Write-Host "SLB Server Domain: " $slbServerHostOrDomain.'fqdn-name'
}
Write-Host "Virtual Server Name: " $virtualServer.'virtual-server-name'
Write-Host "Resource Group Name: " $resourceGroupName

# Get vThunder IP Address
$response = Get-AzPublicIpAddress -Name $hostIPName -ResourceGroupName $resourceGroupName
if ($null -eq $response) {
    Write-Error "Failed to get public ip" -ErrorAction Stop
}
$hostIPAddress = $response.IpAddress
Write-Host "Instance Public IP: "$hostIPAddress

# Base URL of AXAPIs
$BaseUrl = -join("https://", $hostIPAddress, "/axapi/v3")

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

# Function to enable ethernet 1
function ConfigureEth1 {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to configure ethernet1 private ip
        AXAPI: /axapi/v3/interface/ethernet/1
    #>
    param (
        $BaseUrl,
        $AuthorizationToken
    )
    # AXAPI ethernet 1 Url
    $Url = -join($BaseUrl, "/interface/ethernet/1")

    # AXAPI interface url headers
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    $Headers.Add("Content-Type", "application/json")

    $ethPrefix = $ParamData.parameters.eth1PrivatePrefix.value
    $prefix = $ethPrefix.Split("/")[-1]

    $Body = "{
        `n  `"ethernet`": {
        `n    `"ifnum`": 1,
        `n    `"action`": `"enable`",
        `n    `"ip`": {
        `n      `"dhcp`": 0,
        `n      `"address-list`": [
        `n        {
        `n          `"ipv4-address`": `"$ethPrivateIPAddress`",
        `n          `"ipv4-netmask`": `"/$prefix`"
        `n        }
        `n      ]
        `n    }
        `n  }
        `n}"

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
    if ($null -eq $response) {
        Write-Error "Failed to configure ethernet ip"
    } else {
        Write-Host "configured ethernet 1 ip"
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
    # AXAPI ethernet 1 Url
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
                "use-if-ip"=1
                "ethernet"=1
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

# Call above functions
# Invoke Get-AuthToken
$AuthorizationToken = Get-AuthToken -BaseUrl $BaseUrl
# Invoke Enable-Eth1
ConfigureEth1 -BaseUrl $BaseUrl -AuthorizationToken $AuthorizationToken
# Invoke CreateServer
ConfigureServer -BaseUrl $BaseUrl -AuthorizationToken $AuthorizationToken
# Invoke ConfigureServiceGroup
ConfigureServiceGroup -BaseUrl $BaseUrl -AuthorizationToken $AuthorizationToken
# Invoke ConfigureVirtualServer
ConfigureVirtualServer -BaseUrl $BaseUrl -AuthorizationToken $AuthorizationToken

if ($uploadSSLCert){
    SSLUpload -BaseUrl $BaseUrl -AuthorizationToken $AuthorizationToken
}
# Invoke WriteMemory
WriteMemory -BaseUrl $BaseUrl -AuthorizationToken $AuthorizationToken
