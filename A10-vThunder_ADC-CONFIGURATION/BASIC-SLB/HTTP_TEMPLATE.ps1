<#
.PARAMETER resource group
Name of resource group
.EXAMPLE
To run script execute .\<name-of-script> <resource-group-name>
.Description
Script to create a SLB HTTP Template.
Functions:
    1. CreateSlbTemplateHttp
#>


# Get vthunder slb parameter file content
$absoluteFilePath = -join($PSScriptRoot,"\", "SLB_CONFIG_PARAM.json")
$slbParamData = Get-Content -Raw -Path $absoluteFilePath | ConvertFrom-Json -AsHashtable
if ($null -eq $slbParamData) {
    Write-Error "SLB_CONFIG_PARAM.json file is missing." -ErrorAction Stop
}

function CreateSlbTemplateHttp {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to create slb template http
        AXAPI: /axapi/v3/slb/template/http
    #>
    param (
        $baseUrl,
        $authorizationToken
    )
    $url = -join($baseUrl, "/slb/template/http")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $headers.Add("Content-Type", "application/json")

    $httpTemplateList = $slbParamData.parameters.httpList.value
    $body = @{
        "http-list"= $httpTemplateList
    }
    $body = $body | ConvertTo-Json -Depth 6
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body
    if ($null -eq $response) {
        Write-Error "Failed to create slb http template"
    } else {
        Write-Host "Slb Http Template Created."
    }
}

