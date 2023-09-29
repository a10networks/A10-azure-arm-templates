<#
.PARAMETER resource group
    1.vThunderProcessingIP
.Description
    Script for applying glm license on vthunder.
Functions:
    1. GetAuthToken
    2. GetApplianceUuid
    3. ActivateLicense
    4. ConfigurePrimaryDns
    5. ConfigureGlm
    6. GlmRequestSend
    7. WriteMemory
#>
param (
    [Parameter(Mandatory=$True)]
    [String] $vThunderProcessingIP
)

# Get config data from variable
$glmData = Get-AutomationVariable -Name glmParam
$glmParamData = $glmData | ConvertFrom-Json

$vThUserName = Get-AutomationVariable -Name vThUserName
$vThPassword = Get-AutomationVariable -Name vThCurrentPassword
$oldPassword = Get-AutomationVariable -Name vThDefaultPassword

if ($null -eq $glmParamData) {
    Write-Error "GLM Param data is missing." -ErrorAction Stop
}

#host_name of glm portal
$hostName = "https://glm.a10networks.com/"

#user_name and user_password for glm portal sign in
$userName = $glmParamData.userName
if ($null -eq $userName -or "" -eq $userName) {
    Write-Error "Provide GLM USer Name" -ErrorAction Stop
}

$userPassword = $glmParamData.userPassword
if ($null -eq $userName -or "" -eq $userPassword) {
    Write-Error "Provide GLM USer Password" -ErrorAction Stop
}

$entitlementToken = $glmParamData.entitlementToken
$activationToken = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($userName+':'+$userPassword))

# Axapi Authentication call
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

function GetApplianceUuid {
     <#
        .DESCRIPTION
        Function to get Appliance Uuid
        AXAPI: /interface/v1/users/licenses
        .PARAMETER base_url authorizationToken
        Base url of AXAPI
        authorizationToken of axapi
    #>
    param (
        $authorizationToken,
        $baseUrl
    )
    $urlUUID = -join($baseUrl, "/file/license/oper")
    # [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "A10 $authorizationToken")
    $headers.Add("Content-Type", "application/json")
    # $urlUUID = -join("https://", $host_ip_address, "/axapi/v3/file/license/oper")
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-RestMethod -Uri $urlUUID -Method 'GET' -Headers $headers
    $hostUUID = $response.license.oper.{host-id}
    if ($null -eq $hostUUID) {
        Write-Error "Falied to get Appliance UUID from glm API" -ErrorAction Stop
    }
    return $hostUUID

}

function ActivateLicense {

    <#
        .DESCRIPTION
        Function to activate licenses
        GLM: /activations
        .PARAMETER applianceId
        appliance Id of vThunder
    #>

    param(
        $applianceId
    )
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Basic $activationToken")
    $headers.Add("Content-Type", "application/json")

    $body = "{
    `n    `"activation`": {
    `n        `"token`": `"$entitlementToken`",
    `n        `"appliance_uuid`": `"$applianceId`",
    `n        `"version`": `"4.1 or newer`"
    `n    }
    `n}
    `n
    `n"

    $glmURL = $hostName + 'activations'
    $response = Invoke-RestMethod $glmURL -Method 'POST' -Headers $headers -Body $body
}

function ConfigurePrimaryDns {
    <#
        .DESCRIPTION
        Function to Configure Primary Dns
        AXAPI: /ip/dns/primary
        .PARAMETER base_url authorizationToken applianceId
        Base url of AXAPI
        authorizationToken of axapi
        applianceId of the vThunder
    #>
    param (
        $authorizationToken,
        $applianceId,
        $baseUrl
    )
    $urlDNS = -join($baseUrl, "/ip/dns/primary")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "A10 $authorizationToken")
    $headers.Add("Content-Type", "application/json")
    $body = "{
    `n  `"primary`": {
    `n    `"ip-v4-addr`": `"8.8.8.8`",
    `n    `"uuid`": `"$applianceId`"
    `n  }
    `n}"

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-RestMethod -Uri $urlDNS -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json
    if ($null -eq $response) {
        Write-Error "failed to configure primary dns" -ErrorAction Stop
    }

}

function ConfigureGlm {

    <#
        .DESCRIPTION
        Function to Configure Glm
        AXAPI: /interface/v1/users/glm
        .PARAMETER base_url authorizationToken
        Base url of AXAPI
        authorizationToken of axapi
    #>
    param (
        $authorizationToken,
        $baseUrl
    )
    $urlGLM = -join($baseUrl, "/glm")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "A10 $authorizationToken")
    $headers.Add("Content-Type", "application/json")

    $body = "{
        `n  `"glm`": {
        `n    `"use-mgmt-port`": 1,
        `n    `"enable-requests`": 1,
        `n    `"token`": `"$entitlementToken`"
        `n  }
        `n}"

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-RestMethod -Uri $urlGLM -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json
    if ($null -eq $response) {
        Write-Error "failed to configure glm configuration" -ErrorAction Stop
    }
}

function GlmRequestSend {
    <#
        .DESCRIPTION
        Function to Configure Glm
        AXAPI: /interface/v1/users/glm
        .PARAMETER base_url authorizationToken
        Base url of AXAPI
        authorizationToken of axapi
    #>

    param (
        $authorizationToken,
        $baseUrl
    )
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "A10 $authorizationToken")
    $headers.Add("Content-Type", "application/json")
    $urlGlmSend = -join($baseUrl, "/glm/send")
    # $url_glmsend = -join("https://", $host_ip_address, "/axapi/v3/glm/send")

    $body = "{
    `n  `"send`": {
    `n    `"license-request`": 1
    `n  }
    `n}"

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-RestMethod -Uri $urlGlmSend -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json
#    Write-Host $response
}

function WriteMemory {
    <#
        .PARAMETER authorization_token baseUrl
        AXAPI authorization token
        baseUrl of the AXAPI
        .DESCRIPTION
        Function to save configurations on active partition
        AXAPI: /axapi/v3/active-partition
        AXAPI: /axapi/v3//write/memory
    #>
    param (
        $authorizationToken,
        $baseUrl
    )
    $url = -join($baseUrl, "/active-partition")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-RestMethod -Uri $url -Method 'GET' -Headers $headers
    $partition = $response.'active-partition'.'partition-name'

    if ($null -eq $partition) {
        Write-Error "Failed to get partition name"
    } else {
        $urlMEM = -join($baseUrl, "/write/memory")
        $headers1 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers1.Add("Authorization", -join("A10 ", $authorizationToken))
        $headers1.Add("Content-Type", "application/json")

        $body = "{
        `n  `"memory`": {
        `n    `"partition`": `"$partition`"
        `n  }
        `n}"
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $response = Invoke-RestMethod -Uri $urlMEM -Method 'POST' -Headers $headers1 -Body $body
        if ($null -eq $response) {
            Write-Error "Failed to run write memory command"
        } else {
            Write-Host "Configurations are saved on partition: "$partition
        }
    }
}

function vth_logout{
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
        $BaseUrl,
        $AuthorizationToken
    )

    $Url = -join($BaseUrl, "/logoff")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-RestMethod -Method 'GET' -Uri $Url -Headers $headers

    if ($null -eq $response) {
        Write-Error "Failed to configure SSL certificate"
    } else {
        Write-Host "SSL Configured."
    }

}

$vthunderBaseUrl = -join("https://", $vThunderProcessingIP, "/axapi/v3")

$authorizationToken = GetAuthToken -baseUrl $vthunderBaseUrl -vThPass $vThPassword

if ($authorizationToken -eq 401){
    $authorizationToken = GetAuthToken -baseUrl $vthunderBaseUrl -vThPass $oldPassword
}

$applianceUUID = GetApplianceUuid -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken
Write-Output "appliance_uuid : " $applianceUUID

ActivateLicense -applianceId $applianceUUID
Write-Output "ActivateLicense "

ConfigurePrimaryDns -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken -applianceId $applianceUUID
Write-Output "ConfigurePrimaryDns "

ConfigureGlm -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken
Write-Output "ConfigureGlm "

GlmRequestSend -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken
Write-Output "GlmRequestSend "

WriteMemory -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken
Write-Host "WriteMemory "

Write-Host "apply license"

vth_logout -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken -vthunderIP $vThunderProcessingIP

return $applianceUUID