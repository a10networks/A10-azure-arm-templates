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

$vThUserName = Get-AutomationVariable -Name vThUserName
$vThPassword = Get-AutomationVariable -Name vThCurrentPassword
$oldPassword = Get-AutomationVariable -Name vThDefaultPassword

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
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $url = -join($baseUrl, "/acos-events/message-selector")
    $response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $body
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
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    $url = -join($baseUrl, "/acos-events/log-server")
    $response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $body
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
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $url = -join($baseUrl, "/acos-events/collector-group")
    $response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $body
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
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $url = -join($baseUrl, "/acos-events/template")
    $response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $body
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
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $url = -join($baseUrl, "/acos-events/active-template")
    $response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $body
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
    $headers.Add("Content-Type", "application/json")
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-RestMethod -Uri $url -Method 'GET' -Headers $headers
    $partition = $response.'active-partition'.'partition-name'

    if ($null -eq $partition) {
        Write-Error "Failed to get partition name"
    } else {
        $url = -join($baseUrl, "/write/memory")

        $body = "{
        `n  `"memory`": {
        `n    `"partition`": `"$partition`"
        `n  }
        `n}"

        $headers1 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers1.Add("Authorization", -join("A10 ", $authorizationToken))
        $headers1.Add("Content-Type", "application/json")
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $response = Invoke-RestMethod -Uri $url -Method 'POST' -Headers $headers1 -Body $body
        if ($null -eq $response) {
            Write-Error "Failed to run write memory command"
        } else {
            Write-Host "Configurations are saved on partition: "$partition
        }
    }
}

$vthunderBaseUrl = -join("https://", $vThunderProcessingIP, "/axapi/v3")

$authorizationToken = GetAuthToken -baseUrl $vthunderBaseUrl -vThPass $vThPassword

if ($authorizationToken -eq 401){
    $authorizationToken = GetAuthToken -baseUrl $vthunderBaseUrl -vThPass $oldPassword
}

AcosEventsMessageSelector -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken

AcosEventsLogServer -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken

AcosEventsCollectorGroup -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken

AcosEventsTemplate -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken

AcosEventsActiveTemplate -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken

WriteMemory -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken