<#
.EXAMPLE
To run script execute .\<name-of-script>
.Description
Script for applying glm license on vthunder.
Functions:
    1. UserLogin
    2. GetLicenses
    3. GetAuthToken
    4. GetApplianceUuid
    5. ActivateLicense
    6. ConfigurePrimaryDns
    7. ConfigureGlm
    7. WriteMemory
#>

# Get resource group name
$resData = Get-Content -Raw -Path ARM_TMPL_3NIC_2VM_AUTOMATION_ACCOUNT_PARAM.json | ConvertFrom-Json -AsHashtable
Write-Output $resData

$resourceGroupName = $resData.resourceGroupName

Write-Host "Executing 3NIC-GLM-Configuration"

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

$glm_param_data = Get-Content -Raw -Path ARM_TMPL_3NIC_2VM_GLM_CONFIG_PARAM.json | ConvertFrom-Json -AsHashtable

if ($null -eq $glm_param_data) {
    Write-Error "ARM_TMPL_3NIC_2VM_GLM_CONFIG_PARAM.json file is missing." -ErrorAction Stop
}

#host_name of glm portal
$host_name = "https://glm.a10networks.com/"

#user_name and user_password for glm portal sign in
$user_name = $glm_param_data.parameters.user_name.value
if ($null -eq $user_name -or "" -eq $user_name) {
    $user_name = Read-Host -Prompt "Enter your user name"
}

$user_password = $glm_param_data.parameters.user_password.value
if ($null -eq $user_name -or "" -eq $user_password) {
    $user_password_encryption = Read-Host "Enter password" -AsSecureString
    $user_password = ConvertFrom-SecureString $user_password_encryption -AsPlainText
}

$entitlement_token = $glm_param_data.parameters.entitlement_token.value
$activation_token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($user_name+':'+$user_password))

#get Pulbic Ip name and Public Ip address

# Get vthunder 3 nic parameter file content
$ParamData = Get-Content -Raw -Path ARM_TMPL_3NIC_2VM_PARAM.json | ConvertFrom-Json -AsHashtable
if ($null -eq $ParamData) {
    Write-Error "ARM_TMPL_3NIC_2VM_PARAM.json file is missing." -ErrorAction Stop
}

# Get arguments from parameter file
$host1MgmtName = $ParamData.parameters.nic1Name_vthunder1.value
$host2MgmtName = $ParamData.parameters.nic1Name_vthunder2.value

# Get vThunder IP Address
function GetHostIpAdders {
    <#
        .PARAMETER hostMgmtName
        Base url of AXAPI
        .OUTPUTS
        Authorization token
        .DESCRIPTION
        Function to get Authorization token from axapi
        AXAPI: /axapi/v3/auth
    #>
    param (
        $hostMgmtName,
        $resourceGroupName
    )

    $response = Get-AzNetworkInterface -Name $hostMgmtName -ResourceGroupName $resourceGroupName
    $vmIPName = $response.IpConfigurations.PublicIpAddress.Id.Split('/')[-1]
    $response = Get-AzPublicIpAddress -Name $vmIPName -ResourceGroupName $resourceGroupName
    if ($null -eq $response) {
        Write-Error "Failed to get public ip" -ErrorAction Stop
    }
    $vmIPAddress = $response.IpAddress
    return $vmIPAddress
}

$vm1IPAddress = GetHostIpAdders -hostMgmtName $host1MgmtName -resourceGroupName $resourceGroupName
Write-Host "vThunder1 Public IP: "$vm1IPAddress
$vm2IPAddress = GetHostIpAdders -hostMgmtName $host2MgmtName -resourceGroupName $resourceGroupName
Write-Host "vThunder2 Public IP: "$vm2IPAddress

function UserLogin {
    <#
        .OUTPUTS
        User token for authentication for glm api's 
        .DESCRIPTION
        Function to get user token
        AXAPI: /interface/v1/users/sign_in
    #>

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")

    $body = "{
    `n  `"user`": {
    `n    `"email`": `"$user_name`",
    `n    `"password`": `"$user_password`",
    `n    `"code`": 0
    `n  }
    `n}"
    
    $login_url = -join($host_name, "/interface/v1/users/sign_in")
    $response = Invoke-RestMethod -Uri $login_url -Method 'POST' -Headers $headers -Body $body
    $user_token= $response.user_token
    if ($null -eq $user_token) {
        Write-Error "Falied to get user token from glm API" -ErrorAction Stop
    }
    return $user_token
    

}

# Axapi Authentication call
function GetAuthToken {
    <#
        .PARAMETER base_url
        Base url of AXAPI
        .OUTPUTS
        Authorization token
        .DESCRIPTION
        Function to get Authorization token from axapi
        AXAPI: /axapi/v3/auth
    #>
    param (
        $BaseUrl
    )

    # AXAPI Auth url
    $url = -join($BaseUrl, "/auth")
    # AXAPI header
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    # AXAPI Auth url json body
    $body = "{
    `n    `"credentials`": {
    `n        `"username`": `"admin`",
    `n        `"password`": `"a10`"
    `n    }
    `n}"
    # Invoke Auth url
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
    # fetch Authorization token from response
    $authorization_token = $response.authresponse.signature
    if ($null -eq $authorization_token) {
        Write-Error "Falied to get authorization token from AXAPI" -ErrorAction Stop
    }
    return $authorization_token
}

function GetApplianceUuid {
     <#
        .OUTPUTS
        get the licenses id
        .DESCRIPTION
        Function to get licenses id
        AXAPI: /interface/v1/users/licenses
    #>
    param (
        $authorization_token,
        $BaseUrl
    )
    $url_uuid = -join($BaseUrl, "/file/license/oper")
    # [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "A10 $authorization_token")
    $headers.Add("Content-Type", "application/json")
    # $url_uuid = -join("https://", $host_ip_address, "/axapi/v3/file/license/oper")
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url_uuid -Method 'GET' -Headers $headers
    $host_uuid = $response.license.oper.{host-id}
    if ($null -eq $host_uuid) {
        Write-Error "Falied to get Appliance UUID from glm API" -ErrorAction Stop
    }
    return $host_uuid

}

function ActivateLicense {

    <#
        .OUTPUTS
        get the licenses id
        .DESCRIPTION
        Function to get licenses id
        AXAPI: /interface/v1/users/licenses
    #>

    param(
        $appliance_uuid
    )
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Basic $activation_token")
    $headers.Add("Content-Type", "application/json")

    $body = "{
    `n    `"activation`": {
    `n        `"token`": `"$entitlement_token`",
    `n        `"appliance_uuid`": `"$appliance_uuid`",
    `n        `"version`": `"4.1 or newer`"
    `n    }
    `n}
    `n
    `n"

    $response = Invoke-RestMethod 'https://glm.a10networks.com/activations' -Method 'POST' -Headers $headers -Body $body
    if ($null -eq $response) {
        Write-Error "License activation failed" -ErrorAction Stop
    }
}

function ConfigurePrimaryDns {
    <#
        .OUTPUTS
        get the licenses id
        .DESCRIPTION
        Function to get licenses id
        AXAPI: /interface/v1/users/licenses
    #>
    param (
        $authorization_token,
        $appliance_uuid,
        $BaseUrl
    )
    $url_dns = -join($BaseUrl, "/ip/dns/primary")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "A10 $authorization_token")
    $headers.Add("Content-Type", "application/json")
    $body = "{
    `n  `"primary`": {
    `n    `"ip-v4-addr`": `"8.8.8.8`",
    `n    `"uuid`": `"$appliance_uuid`"
    `n  }
    `n}"

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url_dns -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json
    if ($null -eq $response) {
        Write-Error "failed to configure primary dns" -ErrorAction Stop
    }

}

function ConfigureGlm {

    <#
        .OUTPUTS
        get the licenses id
        .DESCRIPTION
        Function to get licenses id
        AXAPI: /interface/v1/users/licenses
    #>
    param (
        $authorization_token,
        $BaseUrl
    )
    $url_glm = -join($BaseUrl, "/glm")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "A10 $authorization_token")
    $headers.Add("Content-Type", "application/json")

    $body = "{
        `n  `"glm`": {
        `n    `"use-mgmt-port`": 1,
        `n    `"enable-requests`": 1,
        `n    `"token`": `"$entitlement_token`"
        `n  }
        `n}"

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url_glm -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json
    if ($null -eq $response) {
        Write-Error "failed to configure glm configuration" -ErrorAction Stop
    }

}

function GlmRequestSend {

    param (
        $authorization_token,
        $BaseUrl
    )
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "A10 $authorization_token")
    $headers.Add("Content-Type", "application/json")
    $url_glm_send = -join($BaseUrl, "/glm/send")
    # $url_glmsend = -join("https://", $host_ip_address, "/axapi/v3/glm/send")

    $body = "{
    `n  `"send`": {
    `n    `"license-request`": 1
    `n  }
    `n}"

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url_glm_send -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json
#    Write-Host $response
}

function WriteMemory {
    <#
        .PARAMETER authorization_token
        AXAPI authorization token
        .DESCRIPTION
        Function to save configurations on active partition
        AXAPI: /axapi/v3/active-partition
        AXAPI: /axapi/v3//write/memory
    #>
    param (
        $authorization_token,
        $BaseUrl
    )
    $url = -join($BaseUrl, "/active-partition")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorization_token))

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'GET' -Headers $headers
    $partition = $response.'active-partition'.'partition-name'

    if ($null -eq $partition) {
        Write-Error "Failed to get partition name"
    } else {
        $url_mem = -join($BaseUrl, "/write/memory")
        $headers.Add("Content-Type", "application/json")

        $body = "{
        `n  `"memory`": {
        `n    `"partition`": `"$partition`"
        `n  }
        `n}"
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url_mem -Method 'POST' -Headers $headers -Body $body
        if ($null -eq $response) {
            Write-Error "Failed to run write memory command"
        } else {
            Write-Host "Configurations are saved on partition: "$partition
        }
    }
}

$vms = @($vm1IPAddress, $vm2IPAddress)

foreach ($vm in $vms) {

    $vthunderBaseUrl = -join("https://", $vm, "/axapi/v3")

    $user_auth_token = UserLogin
    Write-Host "user_auth_token : " $user_auth_token

    # GetAllSubscriptionsLicenses -user_auth_token $user_auth_token
    $authorization_token = GetAuthToken -BaseUrl $vthunderBaseUrl
    Write-Host "authorization_token : " $authorization_token

    $appliance_uuid = GetApplianceUuid -BaseUrl $vthunderBaseUrl -authorization_token $authorization_token
    Write-Host "appliance_uuid : " $appliance_uuid

    ActivateLicense -appliance_uuid $appliance_uuid
    Write-Host "ActivateLicense "

    ConfigurePrimaryDns -BaseUrl $vthunderBaseUrl -authorization_token $authorization_token -appliance_uuid $appliance_uuid
    Write-Host "ConfigurePrimaryDns "

    ConfigureGlm -BaseUrl $vthunderBaseUrl -authorization_token $authorization_token
    Write-Host "ConfigureGlm "

    GlmRequestSend -BaseUrl $vthunderBaseUrl -authorization_token $authorization_token
    Write-Host "GlmRequestSend "

    WriteMemory -BaseUrl $vthunderBaseUrl -authorization_token $authorization_token
    Write-Host "WriteMemory "

    Write-Host "apply license"

}
