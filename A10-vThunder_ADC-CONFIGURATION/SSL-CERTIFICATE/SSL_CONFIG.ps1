<#
.EXAMPLE
To run script execute .\<name-of-script>
.Description
Script to configure a thunder instance as SLB.
Functions:
    1. Get-AuthToken
    2. SSLUpload
    3. WriteMemory
    4. VThLogout
#>

# Get resource group name

Write-Host "Executing SSL-Configuration"

# Get SSL_PARAM.json file content
$absoluteFilePath = -join($PSScriptRoot,"\", "SSL_CONFIG_PARAM.json")
$sslParamData = Get-Content -Raw -Path $absoluteFilePath | ConvertFrom-Json -AsHashtable
if ($null -eq $sslParamData) {
    Write-Error "SSL_CONFIG_PARAM.json file is missing." -ErrorAction Stop
}

$vThUsername = $sslParamData.parameters.vThUsername
# Get arguments
$hostIPAddress = $sslParamData.parameters.hostIPAddress.vThunderIP


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
$timeout = $sslParamData.parameters.sslConfig.requestTimeOut

if ($uploadSSLCert)
    {
        $path = $sslParamData.parameters.sslConfig.path
        if ($null -eq $path) {
                Write-Error "Please provide the certificate file path" -ErrorAction Stop
            }
        $isExist = Test-Path -Path $path -PathType Leaf
        if ($False -eq $isExist){
            Write-Error "Certificate file is not present on given path" -ErrorAction Stop
        }

        $file = $sslParamData.parameters.sslConfig.file
        if ($null -eq $file) {
                Write-Error "Please provide the certificate file name" -ErrorAction Stop
            }
        $certificationType = $sslParamData.parameters.sslConfig.certificationType
        if ($null -eq $certificationType) {
                Write-Error "Please provide the certificate type" -ErrorAction Stop
            }
    }

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


function SSLUpload {
	    <#
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

	$fileBytes = [System.IO.File]::ReadAllBytes($path);
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
		"{`"ssl-cert`": {`"file`": `"$file`", `"action`": `"import`", `"file-handle`": `"$file.$certificationType`", `"certificate-type`": `"$CertificationType`"}}",
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
    $response = Invoke-RestMethod @params -AllowUnencryptedAuthentication:$true -SkipCertificateCheck:$true -SkipHeaderValidation:$false -SkipHttpErrorCheck:$false -DisableKeepAlive:$false -TimeoutSec $timeout
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
    $baseUrl = -join("https://", $vm, "/axapi/v3")
    # Call above functions
    $vThNewPasswordVal = Read-Host "Enter Password for $vm " -AsSecureString
    $vThNewPassword = ConvertFrom-SecureString -SecureString $vThNewPasswordVal -AsPlainText

    # Invoke Get-AuthToken
    $authorizationToken = GetAuthToken -BaseUrl $baseUrl -password $vThNewPassword

    if ($uploadSSLCert){
        SSLUpload -BaseUrl $baseUrl -AuthorizationToken $authorizationToken
    }
    # Invoke WriteMemory
    WriteMemory -BaseUrl $baseUrl -AuthorizationToken $authorizationToken

    VThLogout -BaseUrl $baseUrl -AuthorizationToken $authorizationToken -vthunderIP $vm

}
