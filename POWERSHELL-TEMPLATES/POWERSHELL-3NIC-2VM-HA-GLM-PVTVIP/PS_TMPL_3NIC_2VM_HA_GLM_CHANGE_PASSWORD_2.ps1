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

$ParamData = Get-Content -Raw -Path PS_TMPL_3NIC_2VM_HA_GLM_PVTVIP_PARAM.json | ConvertFrom-Json -AsHashtable
if ($null -eq $ParamData) {
    Write-Error "PS_TMPL_3NIC_2VM_HA_PARAM.json file is missing." -ErrorAction Stop
}

# Get PS_TMPL_2NIC_1VM_SLB_CONFIG_PARAM.json file content
$SLBParamData = Get-Content -Raw -Path PS_TMPL_3NIC_2VM_SLB_CONFIG_PARAM.json | ConvertFrom-Json -AsHashtable
if ($null -eq $SLBParamData) {
    Write-Error "PS_TMPL_3NIC_2VM_HA_SLB_CONFIG_PARAM.json file is missing." -ErrorAction Stop
}

$resourceGroupName = $SLBParamData.parameters.resourceGroupName
if ($null -eq $resourceGroupName) {
    Write-Error "resourceGroupName is missing." -ErrorAction Stop
}
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

$host1MgmtName = $ParamData.parameters.nic1Name_vm1.value
$host2MgmtName = $ParamData.parameters.nic1Name_vm2.value

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

$vms = @($host1IPAddress, $host2IPAddress)
foreach ($vm in $vms)
{
    $vthunderBaseUrl = -join ("https://", $vm, "/axapi/v3")
    $authorizationToken = Get-AuthToken -baseUrl $vthunderBaseUrl
    ChangedAdminPassword -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken

    WriteMemory -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken
}