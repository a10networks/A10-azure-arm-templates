<#
.PARAMETER resource group
    1.vThunderRevokeLicenseUUID
.Description
    Script for revoke glm license from glm portal.
Functions:
    1. LoginGLM
    2. LicenseActivations
    3. RevokeGLM
#>

param (
    [Parameter(Mandatory=$True)]
    [String] $vThunderRevokeLicenseUUID
)

$glmData = Get-AutomationVariable -Name glmParam
$glmParamData = $glmData | ConvertFrom-Json

if ($null -eq $glmParamData) {
    Write-Error "GLM Param data is missing." -ErrorAction Stop
}

#host_name of glm portal
$hostName = "https://glm.a10networks.com/"

#user_name and user_password for glm portal sign in
$username = $glmParamData.userName
if ($null -eq $username -or "" -eq $username) {
    Write-Error "Provide GLM User Name" -ErrorAction Stop
}

$password = $glmParamData.userPassword
if ($null -eq $password -or "" -eq $password) {
    Write-Error "Provide GLM User Password" -ErrorAction Stop
}

$licenseId =  $glmParamData.licenseId
if ($null -eq $licenseId -or "" -eq $licenseId) {
    Write-Error "Provide GLM License ID" -ErrorAction Stop
}

function LoginGLM {
    # Login to glm portal
    $loginHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $loginHeaders.Add("Content-Type", "application/json")

    $loginBody = "{
    `n  `"user`": {
    `n   `"email`": `"$username`",
    `n   `"password`": `"$password`"
    `n    }
    `n}"

	$loginUrl = -join($hostName, '/users/sign_in.json')
    $loginResponse = Invoke-RestMethod $loginUrl -Method 'POST' -Headers $loginHeaders -Body $loginBody
    $loginResponse | ConvertTo-Json
    return $loginResponse
}

function LicenseActivations {
    param (
        $glmToken
    )
    # List of activations
    $licenseHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $licenseHeaders.Add("Content-Type", "application/json")
    $licenseHeaders.Add("X-User-Email", $username)
    $licenseHeaders.Add("X-User-Token", $glmToken)
    $licenseUrl = $hostName+'licenses/'+$licenseId+'/activations.json'
    $licenseResponse = Invoke-RestMethod $licenseUrl -Method 'GET' -Headers $licenseHeaders
    $licenseResponse | ConvertTo-Json
    return $licenseResponse
}

function RevokeGLM {
    param (
        $activationList,
        $vThunderRevokeLicenseUUID,
        $glmToken
    )
    # Revoke GLM License Using UUID
    $revokeHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $revokeHeaders.Add("Content-Type", "application/json")
    $revokeHeaders.Add("X-User-Email", $username)
    $revokeHeaders.Add("X-User-Token", $glmToken)
	$activeVthunder = $activationList[0] | ConvertFrom-Json
    foreach($vThunder in $activeVthunder){
        if ($vThunderRevokeLicenseUUID -eq $vThunder.appliance_uuid){
            $revokeUrl = $hostName+'activations/revoke.json'
            $activeLicId = $vThunder.id
            $body = "{`"license-id`": `"$licenseId`",`"ids`": [`"$activeLicId`"]}"
            Try {
                Invoke-RestMethod $revokeUrl -Method 'PATCH' -Headers $revokeHeaders -Body $body
            } Catch {
                $_.Exception.Response
            }
        }
    }
}

# Get glm token
$glmToken = LoginGLM

# Get activated vthunders
$activationList = LicenseActivations -glmToken $glmToken.user_token

# revoke license
RevokeGLM -activationList $activationList -vThunderRevokeLicenseUUID $vThunderRevokeLicenseUUID -glmToken $glmToken.user_token

Write-Output "Revoke Done"