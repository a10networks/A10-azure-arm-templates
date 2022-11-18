<#
.PARAMETER
	1.vThunderProcessingIP
	2. agentPrivateIP
.Description
    Script to configure a acos event.
Functions:
    1. GetAuthToken
    2. AcosEventsMessageSelector
    3. AcosEventsLogServer
    4. AcosEventsCollectorGroup1
    5. AcosEventsCollectorGroup2
    6. AcosEventsTemplate
    7. AcosEventsActiveTemplate
    8. WriteMemory
#>

param (
     [Parameter(Mandatory=$True)]
     [String] $vThunderProcessingIP,
     [Parameter(Mandatory=$True)]
     [String] $agentPrivateIP
)

# Get resource config from variables
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

$vThUsername = Get-AutomationVariable -Name vThUsername
$vThPassword = Get-AutomationVariable -Name vThPassword

function GetAuthToken {
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
    `n        `"password`": `"$vThPassword`"
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

function AcosEventsMessageSelector {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to create acos-events message-selector configurations
        AXAPI: /axapi/v3/acos-events/message-selector
    #>

    param (
        $baseUrl,
        $authorizationToken
    )

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    $body = "{
    `n  `"message-selector`": {
    `n    `"name`": `"vThunderLog`",
    `n    `"rule-list`": [
    `n      {
    `n        `"index`": 1,
    `n        `"action`": `"send`",
    `n        `"severity-oper`": `"equal-and-higher`",
    `n        `"severity-val`": `"debugging`"
    `n      }
    `n    ]
    `n  }
    `n}"

    $url = -join($baseUrl, "/acos-events/message-selector")
    $response = Invoke-RestMethod -SkipCertificateCheck $url -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json
}

function AcosEventsLogServer {
    <#
    .PARAMETER BaseUrl
    Base url of AXAPI
    .PARAMETER AuthorizationToken
    AXAPI authorization token
    .DESCRIPTION
    Function to create acos-events log-server configurations
    AXAPI: /axapi/v3/acos-events/log-server
    #>
    param (
        $baseUrl,
        $authorizationToken
    )

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    $body = "{
    `n  `"log-server`": {
    `n    `"name`": `"fluentBitLogAgent`",
    `n    `"host`": `"$agentPrivateIP`",
    `n    `"action`": `"enable`",
    `n    `"health-check-disable`": 1,
    `n    `"port-list`": [
    `n      {
    `n        `"port-number`": 514,
    `n        `"protocol`": `"udp`",
    `n        `"action`": `"enable`",
    `n        `"health-check-disable`": 1
    `n      }
    `n    ]
    `n  }
    `n}"

    $url = -join($baseUrl, "/acos-events/log-server")
    $response = Invoke-RestMethod -SkipCertificateCheck $url -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json
}

function AcosEventsCollectorGroup {
    <#
    .PARAMETER BaseUrl
    Base url of AXAPI
    .PARAMETER AuthorizationToken
    AXAPI authorization token
    .DESCRIPTION
    Function to create acos-events collector-group configurations
    AXAPI: /axapi/v3/acos-events/collector-group
    #>

    param (
        $baseUrl,
        $authorizationToken
    )

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    $body = "{
    `n  `"collector-group`": {
    `n    `"name`": `"vThunderSyslog`",
    `n    `"protocol`": `"udp`",
    `n    `"format`": `"syslog`",
    `n    `"facility`": `"local0`",
    `n    `"rate`": 500,
    `n    `"use-mgmt-port`": 0,
    `n    `"log-server-list`": [
    `n      {
    `n        `"name`": `"fluentBitLogAgent`",
    `n        `"port`": 514
    `n      }
    `n    ]
    `n  }
    `n}"

    $url = -join($baseUrl, "/acos-events/collector-group")
    $response = Invoke-RestMethod -SkipCertificateCheck $url -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json

}

function AcosEventsTemplate {
    <#
    .PARAMETER BaseUrl
    Base url of AXAPI
    .PARAMETER AuthorizationToken
    AXAPI authorization token
    .DESCRIPTION
    Function to create acos-events template configurations
    AXAPI: /axapi/v3/acos-events/template
    #>

    param (
        $baseUrl,
        $authorizationToken
    )

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    $body = "{
    `n  `"template`": {
    `n    `"name`": `"fluentbitRemoteServer`",
    `n    `"message-selector-list`": [
    `n      {
    `n        `"name`": `"vThunderLog`",
    `n        `"collector-group-list`": [
    `n          {
    `n            `"name`": `"vThunderSyslog`"
    `n          }
    `n        ]
    `n      }
    `n    ]
    `n  }
    `n}"

    $url = -join($baseUrl, "/acos-events/template")
    $response = Invoke-RestMethod -SkipCertificateCheck $url -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json

}

function AcosEventsActiveTemplate {
    <#
    .PARAMETER BaseUrl
    Base url of AXAPI
    .PARAMETER AuthorizationToken
    AXAPI authorization token
    .DESCRIPTION
    Function to create acos-events template configurations
    AXAPI: /axapi/v3/acos-events/active-template
    #>

    param (
        $baseUrl,
        $authorizationToken
    )

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    $body = "{
    `n  `"active-template`": {
    `n    `"name`": `"fluentbitRemoteServer`"
    `n  }
    `n}"

    $url = -join($baseUrl, "/acos-events/active-template")
    $response = Invoke-RestMethod -SkipCertificateCheck $url -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json

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
        $baseUrl,
        $authorizationToken
    )
    $url = -join($baseUrl, "/active-partition")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'GET' -Headers $headers
    $partition = $response.'active-partition'.'partition-name'

    if ($null -eq $partition) {
        Write-Error "Failed to get partition name"
    } else {
        $url = -join($baseUrl, "/write/memory")
        $headers.Add("Content-Type", "application/json")

        $body = "{
        `n  `"memory`": {
        `n    `"partition`": `"$partition`"
        `n  }
        `n}"
        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
        if ($null -eq $response) {
            Write-Error "Failed to run write memory command"
        } else {
            Write-Host "Configurations are saved on partition: "$partition
        }
    }
}

$vthunderBaseUrl = -join("https://", $vThunderProcessingIP, "/axapi/v3")

$authorizationToken = GetAuthToken -baseUrl $vthunderBaseUrl

AcosEventsMessageSelector -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken

AcosEventsLogServer -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken

AcosEventsCollectorGroup -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken

AcosEventsTemplate -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken

AcosEventsActiveTemplate -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken

WriteMemory -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken