<#
.EXAMPLE
To run script execute .\Change_Password_Setup.ps1
.Description
Script to change password of thunder instance.
Functions:
    1. Get-AuthToken
    2. ChangedAdminPassword
    3. WriteMemory
#>

function Get-AuthToken {
    <#
        .PARAMETER BaseUrl
        Base url of AXAPI
        .OUTPUTS
        Authorization token
        .DESCRIPTION
        Function to get authorization token
        AXAPI: /axapi/v3/auth
    #>
    param (
        $baseUrl,
        $vThUsername,
        $vThOldPass

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
    `n        `"password`": `"$vThOldPass`"
    `n    }
    `n}"
	
	try {
	   	# Invoke Auth url
		$response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method 'POST' -Headers $headers -Body $body -TimeoutSec 10
		# fetch Authorization token from response
		$authorizationToken = $Response.authresponse.signature
		if ($null -eq $authorizationToken) {
			Write-Error "Failed to get auth token from thunder. Please provide valid credentails or unable to connect thunder host." -ErrorAction Stop
		}
		return $authorizationToken
	}
	catch {
		Write-Error "Failed to get auth token from thunder. Please provide valid credentails or unable to connect thunder host."
		return $null
	}


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
        $vthunderBaseUrl,
        $authorizationToken,
        $vThNewPassword
    )
    $Url = -join($vthunderBaseUrl, "/admin/admin/password")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $Headers.Add("Content-Type", "application/json")
    $Body = "{
        `n  `"password`": {
        `n    `"password-in-module`": `"$vThNewPassword`",
        `n    `"encrypted-in-module`": `"Unknown Type: encrypted`"
        `n  }
        `n}"

    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $Url -Method 'POST' -Headers $Headers -Body $Body -TimeoutSec 10
    if ($null -eq $response) {
        Write-Error "Failed to apply new password. Please provide valid credentails or unable to connect thunder host."
        return 0
    } else {
        # Write-Host "Successully password has been changed"
        return 1
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
        Write-Error "Failed to get partition name."
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
            Write-Error "Failed to write in memory."
        } else {
            Write-Host "Password change configurations saved on partition: "$partition
        }
    }
}

Write-Host "Primary conditions for password validation, user should provide the new password according to the given combination: `n`nMinimum length of 9 characters`nMinimum lowercase character should be 1`nMinimum uppercase character should be 1`nMinimum number should be 1`nMinimum special character should be 1`nShould not include repeated characters`nShould not include more than 3 keyboard consecutive characters."
Write-Host "--------------------------------------------------------------------------------------------------------------------`n"

$check = 0
$count = 0
while ($check -ne 1) {
    $vThunderPulbidIP = Read-Host "Enter thunder host/ip"
    $vThunderUsername = Read-Host "Enter thunder username"
    $vThOldPasswordVal = Read-Host "Enter thunder current password" $vThunderPulbidIP -AsSecureString
    $vThOldPass = ConvertFrom-SecureString -SecureString $vThOldPasswordVal -AsPlainText
    $vThNewPasswordVal = Read-Host "Enter thunder new password" -AsSecureString
    $vThNewPassword = ConvertFrom-SecureString -SecureString $vThNewPasswordVal -AsPlainText
    $vThNewPasswordC = Read-Host "Confirm new password" -AsSecureString
    $vThNewPasswordConfirm = ConvertFrom-SecureString -SecureString $vThNewPasswordc -AsPlainText
    if ($vThNewPassword -eq $vThNewPasswordConfirm) {

        $vthunderBaseUrl = -join("https://", $vThunderPulbidIP, "/axapi/v3")
        $authorizationToken = Get-AuthToken -baseUrl $vthunderBaseUrl -vThUsername	$vThunderUsername -vThOldPass $vThOldPass
		
		if($authorizationToken -eq $null){
			continue
		}
		
        $check = ChangedAdminPassword -vthunderBaseUrl $vthunderBaseUrl -authorizationToken $authorizationToken -vThNewPassword $vThNewPassword
        if($check -eq $true) {
            Write-Host "Password successfully changed for" $vThunderPulbidIP
            WriteMemory -baseUrl $vthunderBaseUrl -authorizationToken $authorizationToken
            Write-Host "--------------------------------------------------------------------------------------------------------------------`n"
            $choice = Read-Host "Do you want to continue?,(Y/N)"
            if ($choice -eq "Yes" -or $choice -eq "Y" -or $choice -eq "y") {
                $check = 0
            }
            else {
                $check = 1
            }
            $count = 0
        }
        else {
            
             continue
           
        }
        
        
    }

    else {
        Write-Error "Password doesn't match. Please try again." 
        continue
    }
    
}


