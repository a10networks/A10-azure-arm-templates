<#
.EXAMPLE
To run script execute .\<name-of-script>
.Description
Script for applying glm license on vthunder.
Functions:
    1. UserLogin
    2. GetLicenses
    3. GetAuthToken
    4. ConfigurePrimaryDns
    5. ConfigureGlm
    6. GlmRequestSend
    7. WriteMemory
    8. VThLogout
#>

# Get GLM param file 
$absoluteFilePath = -join($PSScriptRoot,"\", "GLM_CONFIG_PARAM.json")
$glmParamData = Get-Content -Raw -Path $absoluteFilePath | ConvertFrom-Json -AsHashtable
if ($null -eq $glmParamData) {
    Write-Error "GLM_CONFIG_PARAM.json file is missing." -ErrorAction Stop
}

#Get vThunder username
$vThUsername = $glmParamData.parameters.vThUsername.value

#Get public Ip address list
$hostIPAddress = $glmParamData.parameters.hostIPAddress.vThunderIP

#Get entitlement token from glm parameter file
$entitlementToken = $glmParamData.parameters.entitlementToken.value
$dnsPrimary = $glmParamData.parameters.dnsPrimary.value

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
        $baseUrl,
        $password
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
    `n        `"password`": `"$password`"
    `n    }
    `n}"

    # Invoke Auth url
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body

    # fetch Authorization token from response
    $authorizationToken = $response.authresponse.signature
    if ($null -eq $authorizationToken) {
        Write-Error "Falied to get authorization token from AXAPI" -ErrorAction Stop
    }
    return $authorizationToken
}

function ConfigurePrimaryDns {
    <#
        .PARAMETER base_url
        Base url of AXAPI
        .OUTPUTS
        configure primary dns
        .DESCRIPTION
        Function to configure primary dns
        AXAPI: /ip/dns/primary
    #>
    param (
        $authorizationToken,
        $applianceId,
        $baseUrl
    )
    #AXAPI url
    $urlDns = -join($baseUrl, "/ip/dns/primary")

    #AXAPI header
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "A10 $authorizationToken")
    $headers.Add("Content-Type", "application/json")

    #AXAPI json body
    $body = "{
    `n  `"primary`": {
    `n    `"ip-v4-addr`": `"$dnsPrimary`"
    `n  }
    `n}"
    
    #invoke AXAPI url
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $urlDns -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json
    if ($null -eq $response) {
        Write-Error "failed to configure primary dns" -ErrorAction Stop
    }
}

function ConfigureGlm {

    <#
        .PARAMETER base_url
        Base url of AXAPI
        .OUTPUTS
        configuration of glm
        .DESCRIPTION
        Function to configure glm
        AXAPI: /glm
    #>
    param (
        $authorizationToken,
        $baseUrl
    )
    $urlGlm = -join($baseUrl, "/glm")
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

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $urlGlm -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json
    if ($null -eq $response) {
        Write-Error "failed to configure glm configuration" -ErrorAction Stop
    }

}

function GlmRequestSend {

    <# 
        .PARAMETER base_url
        Base url of AXAPI
        .OUTPUTS
        send request for apply glm
        .DESCRIPTION
        Function to send request for glm apply
        AXAPI: /glm/send
    #>

    param (
        $authorizationToken,
        $baseUrl
    )
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "A10 $authorizationToken")
    $headers.Add("Content-Type", "application/json")
    $urlGlmSend = -join($baseUrl, "/glm/send")

    $body = "{
    `n  `"send`": {
    `n    `"license-request`": 1
    `n  }
    `n}"

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $urlGlmSend -Method 'POST' -Headers $headers -Body $body
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
        $authorizationToken,
        $baseUrl
    )
    $url = -join($baseUrl, "/active-partition")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'GET' -Headers $headers
    $partition = $response.'active-partition'.'partition-name'

    if ($null -eq $partition) {
        Write-Error "Failed to get partition name"
    } else {
        $urlMem = -join($baseUrl, "/write/memory")
        $headers.Add("Content-Type", "application/json")

        $body = "{
        `n  `"memory`": {
        `n    `"partition`": `"$partition`"
        `n  }
        `n}"
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $urlMem -Method 'POST' -Headers $headers -Body $body
        if ($null -eq $response) {
            Write-Error "Failed to run write memory command"
        } else {
            Write-Host "Configurations are saved on partition: "$partition
        }
    }
}

function VThLogout{
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
        $baseUrl,
        $vThunderIP,
        $authorizationToken
    )

    $url = -join($baseUrl, "/logoff")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))

    $response = Invoke-RestMethod -Method 'GET' -SkipCertificateCheck -Uri $url -Headers $headers

    if ($null -eq $response) {
        Write-Error "Failed to closed Session ID for $vThunderIP."
    } else {
        Write-Host "Session ID closed for $vThunderIP."
    }

}

foreach ($vm in $hostIPAddress) {
    Write-Host "applying GLM license on : " $vm
    $baseUrl = -join("https://", $vm, "/axapi/v3")

    #get vThunder password
    $vThNewPasswordVal = Read-Host "Enter Password for $vm " -AsSecureString
    $vThNewPassword = ConvertFrom-SecureString -SecureString $vThNewPasswordVal -AsPlainText

    $authorizationToken = GetAuthToken -baseUrl $baseUrl -password $vThNewPassword
    Write-Host "authorization_token : " $authorizationToken

    ConfigurePrimaryDns -authorizationToken $authorizationToken -baseUrl $baseUrl
    Write-Host "ConfigurePrimaryDns "

    ConfigureGlm -authorizationToken $authorizationToken -baseUrl $baseUrl
    Write-Host "ConfigureGlm "

    GlmRequestSend -authorizationToken $authorizationToken -baseUrl $baseUrl
    Write-Host "GlmRequestSend "

    WriteMemory -authorizationToken $authorizationToken -baseUrl $baseUrl
    Write-Host "WriteMemory "

    VThLogout -authorizationToken $authorizationToken -vthunderIP $vm -baseUrl $baseUrl
}
