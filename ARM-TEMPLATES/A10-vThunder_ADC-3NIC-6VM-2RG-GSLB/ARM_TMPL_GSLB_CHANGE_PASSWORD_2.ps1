<#
.EXAMPLE
To run script execute .\<name-of-script>
.Description
Script to change password of thunder instance.
Functions:
    1. Get-AuthToken
    2. ChangedAdminPassword
    3. WriteMemory
#>

# Get ARM_TMPL_GSLB_PARAM.json file content
$ParamData = Get-Content -Raw -Path .\ARM_TMPL_GSLB_PARAM.json | ConvertFrom-Json -AsHashtable
if ($null -eq $ParamData) {
    Write-Error "ARM_TMPL_GSLB_PARAM.json file is missing." -ErrorAction Stop
}

$value = "mgmt"+$ParamData.parameters.region1.value+"1"
$ParamData.parameters["nic1Name_controllerlocation1"] = @{value = $value}
$value = "mgmt"+$ParamData.parameters.region1.value+"2"
$ParamData.parameters["nic1Name_site1location1"] = @{value = $value}
$value = "mgmt"+$ParamData.parameters.region1.value+"3"
$ParamData.parameters["nic1Name_site2location1"] = @{value = $value}
$value = "mgmt"+$ParamData.parameters.region2.value+"1"
$ParamData.parameters["nic1Name_controllerlocation2"] = @{value = $value}
$value = "mgmt"+$ParamData.parameters.region2.value+"2"
$ParamData.parameters["nic1Name_site1location2"] = @{value = $value}
$value = "mgmt"+$ParamData.parameters.region2.value+"3"
$ParamData.parameters["nic1Name_site2location2"] = @{value = $value}

# Get ARM_TMPL_GSLB_SLB_PARAM.json file content
$SLBParamData = Get-Content -Raw -Path .\ARM_TMPL_GSLB_SLB_PARAM.json | ConvertFrom-Json -AsHashtable
if ($null -eq $SLBParamData) {
    Write-Error "ARM_TMPL_GSLB_SLB_PARAM.json file is missing." -ErrorAction Stop
}

$resourceGroupName = $SLBParamData.parameters.resourceGroupName
$vThUsername = $SLBParamData.parameters.vThUsername
$vThLastPasswordVal = Read-Host "Enter Default Password" -AsSecureString
$vThLastPass = ConvertFrom-SecureString -SecureString $vThLastPasswordVal -AsPlainText
$vThNewPasswordVal = Read-Host "Enter a New Password" -AsSecureString
$vThNewPassword = ConvertFrom-SecureString -SecureString $vThNewPasswordVal -AsPlainText
$vThNewPasswordC = Read-Host "Confirm New Password" -AsSecureString
$vThNewPasswordConfirm = ConvertFrom-SecureString -SecureString $vThNewPasswordc -AsPlainText

if ($vThNewPassword -ne $vThNewPasswordConfirm) {
    Write-Error "New Password doesn't match." -ErrorAction Stop
}

# Connect to Azure portal
$status = $null
$status = Connect-AzAccount
if ($null -eq $status) {
    Write-Error "Authentication with Azure Portal Failed" -ErrorAction Stop
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
        $baseUrl
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
    `n        `"password`": `"$vThLastPass`"
    `n    }
    `n}"

    # Invoke Auth url
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
    # fetch Authorization token from response
    $authorizationToken = $Response.authresponse.signature
    if ($null -eq $authorizationToken) {
        Write-Error "Falied to get authorization token from AXAPI" -ErrorAction Stop
    }
    return $authorizationToken
}

function ChangedAdminPassword {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function for changing admin password
        AXAPI: /axapi/v3/admin/{admin-user}/password
    #>
    param (
        $baseUrl,
        $authorizationToken
    )
    $Url = -join($baseUrl, "/admin/admin/password")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $Headers.Add("Content-Type", "application/json")
    $Body = "{
        `n  `"password`": {
        `n    `"password-in-module`": `"$vThNewPassword`",
        `n    `"encrypted-in-module`": `"Unknown Type: encrypted`"
        `n  }
        `n}"

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
    if ($null -eq $response) {
        Write-Error "Failed to change password"
    } else {
        Write-Host "password has been changed"
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
        AXAPI: /axapi/v3/write/memory
    #>
    param (
        $baseUrl,
        $authorizationToken
    )
    $Url = -join($baseUrl, "/active-partition")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $authorizationToken))

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'GET' -Headers $Headers
    $partition = $response.'active-partition'.'partition-name'

    if ($null -eq $partition) {
        Write-Error "Failed to get partition name"
    } else {
        $Url = -join($baseUrl, "/write/memory")
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


$vTh1MgmtName =$ParamData.parameters.nic1Name_site1location1.value
$vTh2MgmtName =$ParamData.parameters.nic1Name_site2location1.value
$vTh3MgmtName =$ParamData.parameters.nic1Name_site1location2.value
$vTh4MgmtName =$ParamData.parameters.nic1Name_site2location2.value
$vTh5MgmtName =$ParamData.parameters.nic1Name_controllerlocation1.value
$vTh6MgmtName =$ParamData.parameters.nic1Name_controllerlocation2.value

$vth_management = @($vTh1MgmtName, $vTh2MgmtName, $vTh3MgmtName, $vTh4MgmtName, $vTh5MgmtName, $vTh6MgmtName)

#vms will store the public ip addresses of the management interfaces of sites
$vms = New-Object System.Collections.ArrayList

foreach ($vth_name in $vth_management)
{
    $response = Get-AzNetworkInterface -Name $vth_name -ResourceGroupName $resourceGroupName
    $host1IPName = $response.IpConfigurations.PublicIpAddress.Id.Split('/')[-1]
    $response = Get-AzPublicIpAddress -Name $host1IPName -ResourceGroupName $resourceGroupName
    if ($null -eq $response) {
        Write-Error "Failed to get public ip" -ErrorAction Stop
    }
    $hostIPAddress = $response.IpAddress
    [void]$vms.Add($hostIPAddress)
}

foreach ($vm in $vms)
{
    $vthunderBaseUrl = -join ("https://", $vm, "/axapi/v3")
    $authorizationToken = Get-AuthToken -baseUrl $vthunderBaseUrl
    ChangedAdminPassword -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken

    WriteMemory -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken
}