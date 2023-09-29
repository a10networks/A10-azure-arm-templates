<#
.PARAMETER
    1.vThunderProcessingIP
.Description
    Script to configure a thunder instance as SSL.
Functions:
    1. Get-AuthToken
    2. SSLUpload
#>

param (
    [Parameter(Mandatory=$True)]
    [String] $vThunderProcessingIP
)

# Get resource config from variables
$azureAutoScaleResources = Get-AutomationVariable -Name azureAutoScaleResources
$azureAutoScaleResources = $azureAutoScaleResources | ConvertFrom-Json
$vThUserName = Get-AutomationVariable -Name vThUserName
$vThPassword = Get-AutomationVariable -Name vThCurrentPassword
$oldPassword = Get-AutomationVariable -Name vThDefaultPassword

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

#get variables
$sslData = Get-AutomationVariable -Name sslParam
$sslParamData = $sslData | ConvertFrom-Json
if ($null -eq $sslParamData) {
    Write-Error "SSL Param data is missing." -ErrorAction Stop
}

$storageAccountName = $azureAutoScaleResources.storageAccountName
$container = $sslParamData.containerName
$storageAccountKey = $sslParamData.storageAccountKey
$timeOut = $sslParamData.requestTimeout
$path = $sslParamData.path
$path = $path.Split("\")[-1]
$file = $sslParamData.file
$certificationType = $sslParamData.certificationType

if ($null -eq $path) {
		Write-Error "Please provide the certificate file path" -ErrorAction Stop
	}

$isExist = Test-Path -Path $path -PathType Leaf
    if ($False -eq $isExist){
        $contx = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
		Get-AzStorageBlob -Container $container -Blob $path -Context $contx | Get-AzStorageBlobContent
    }

if ($null -eq $file) {
		Write-Error "Please provide the certificate file name" -ErrorAction Stop
	}

if ($null -eq $certificationType) {
		Write-Error "Please provide the certificate type" -ErrorAction Stop
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

function SSLUpload {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function to configure service group
        AXAPI: /file/ssl-cert
    #>
    param (
        $baseUrl,
        $authorizationToken
    )

    $url = "$baseUrl/file/ssl-cert"
    $boundary = "----WebKitFormBoundary2f4l91ArINVV3IAK"

    $curDir = Get-Location
    $filePath = Join-Path -Path $curDir -ChildPath $path
    $fileBytes = [System.IO.File]::ReadAllBytes($filePath);
    $fileEnc = [System.Text.Encoding]::GetEncoding('ISO-8859-1').GetString($fileBytes);

    $LF = "`r`n";

    $headers = @{
            Authorization = "A10 $authorizationToken"
        "Content-Type" = "multipart/form-data; boundary=$boundary"
    }

    $bodyLines = (
        "--$boundary",
        "Content-Disposition: form-data; name=`"json`"; filename=`"blob`"",
        "Content-Type: application/json",
        "",
        "{`"ssl-cert`": {`"file`": `"$file`", `"action`": `"import`", `"file-handle`": `"$file.$certificationType`", `"certificate-type`": `"$certificationType`"}}",
        "--$boundary",
        "Content-Disposition: form-data; name=`"file`"; filename=`"$file.$certificationType`"",
        "Content-Type: application/octet-stream",
        "",
        $fileEnc,
        "--$boundary--$LF"
    ) -join $LF

    $params = @{
        Uri         = $url
        Body        = $bodyLines
        Method      = 'Post'
        Headers     = $headers
    }
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-RestMethod @params -TimeoutSec $timeOut
    if ($null -eq $response) {
        Write-Error "Failed to configure SSL certificate"
    } else {
        Write-Host "SSL Configured."
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
        $vthunderIP,
        $AuthorizationToken
    )

    $Url = -join($BaseUrl, "/logoff")
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", -join("A10 ", $AuthorizationToken))
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-RestMethod -Method 'GET' -Uri $Url -Headers $headers

    if ($null -eq $response) {
        Write-Error "Failed to closed Session ID for $vthunderIP ."
    } else {
        Write-Host "Session ID closed for $vthunderIP ."
    }

}

$vthunderBaseUrl = -join("https://", $vThunderProcessingIP, "/axapi/v3")
# Get Authorization Token

$authorizationToken = Get-AuthToken -baseUrl $vthunderBaseUrl -vThPass $vThPassword

if ($authorizationToken -eq 401){
    $authorizationToken = Get-AuthToken -baseUrl $vthunderBaseUrl vThPass $oldPassword
}
# Write-Host $authorizationToken
SSLUpload -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken

vth_logout -BaseUrl $vthunderBaseUrl -AuthorizationToken $authorizationToken -vthunderIP $vThunderProcessingIP