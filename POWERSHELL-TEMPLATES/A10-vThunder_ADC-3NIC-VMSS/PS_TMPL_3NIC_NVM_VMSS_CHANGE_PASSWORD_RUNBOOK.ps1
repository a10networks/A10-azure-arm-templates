param (
    [Parameter(Mandatory=$False)]
    [String] $vThunderProcessingIP = $null
)

# Get the resource config from variables
$azureAutoScaleResources = Get-AutomationVariable -Name azureAutoScaleResources
$azureAutoScaleResources = $azureAutoScaleResources | ConvertFrom-Json 
if ($null -eq $azureAutoScaleResources) {
    Write-Error "azureAutoScaleResources data is missing." -ErrorAction Stop
}
# Get variables value
$resourceGroupName = $azureAutoScaleResources.resourceGroupName
$vThunderScaleSetName = $azureAutoScaleResources.vThunderScaleSetName

# Authenticate with Azure Portal
$appId = $azureAutoScaleResources.appId
$secret = Get-AutomationVariable -Name clientSecret
$tenantId = $azureAutoScaleResources.tenantId

$secureStringPwd = $secret | ConvertTo-SecureString -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appId, $secureStringPwd
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId

# Get automation account variables
$vThUserName = Get-AutomationVariable -Name vThUserName

# Get New password from automation variable
$vThNewPassword = Get-AutomationVariable -Name vThNewPassword
if ($vThNewPassword.GetType().Name -ne "String") {
    Write-Error "New password data type is not string or encrypted string" -ErrorAction Stop
}

# Get Default password from automation variable
$vThDefaultPassword = Get-AutomationVariable -Name vThDefaultPassword 

# Get current password from automation variable
$vThCurrentPassword = Get-AutomationVariable -Name vThCurrentPassword
if ($vThCurrentPassword.GetType().Name -ne "String") {
    Write-Error "Current password data type is not string or encrypted string" -ErrorAction Stop
}

# Get flag from automation variable
$isPasswordChangesForAll = Get-AutomationVariable -Name vThNewPassApplyFlag
$isPasswordChangesForAll = $isPasswordChangesForAll.Trim().ToUpper()


function GetAuthToken {
    <#
        .PARAMETER baseUrl
        Base url of AXAPI
        .OUTPUTS
        Authorization token
        .DESCRIPTION
        Function to get Authorization token
        AXAPI: /axapi/v3/auth
    #>
    param (
        $baseUrl,
        $vThunderPassword
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
    `n        `"password`": `"$vThunderPassword`"
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

function ChangedAdminPassword {
    <#
        .PARAMETER baseUrl
        Base url of AXAPI
        .PARAMETER AuthorizationToken
        AXAPI authorization token
        .DESCRIPTION
        Function for changing admin password
        AXAPI: /axapi/v3/admin/{admin-user}/password
    #>
    param (
        $baseUrl,
        $authorizationToken,
        $vThunderPassword
    )
    $Url = -join($baseUrl, "/admin/admin/password")
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", -join("A10 ", $authorizationToken))
    $Headers.Add("Content-Type", "application/json")
    $Body = "{
        `n  `"password`": {
        `n    `"password-in-module`": `"$vThunderPassword`",
        `n    `"encrypted-in-module`": `"Unknown Type: encrypted`"
        `n  }
        `n}"

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $response = Invoke-RestMethod -Uri $Url -Method 'POST' -Headers $Headers -Body $Body
    if ($null -eq $response) {
        return 400
    } else {
        return 200
    }
}

function WriteMemory {	
    <#	
        .PARAMETER baseUrl	
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
    $Headers.Add("Content-Type", "application/json")	
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}	
    $response = Invoke-RestMethod -Uri $Url -Method 'GET' -Headers $Headers	
    $partition = $response.'active-partition'.'partition-name'	
    if ($null -eq $partition) {	
        Write-Error "Failed to get partition name"	
    } else {	
        $Url = -join($baseUrl, "/write/memory")	
        $Headers1 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"	
        $Headers1.Add("Authorization", -join("A10 ", $authorizationToken))	
        $Headers1.Add("Content-Type", "application/json")	
        $Body = "{	
        `n  `"memory`": {	
        `n    `"partition`": `"$partition`"	
        `n  }	
        `n}"	
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}	
        $response = Invoke-RestMethod -Uri $Url -Method 'POST' -Headers $Headers1 -Body $Body	
        if ($null -eq $response) {	
            Write-Error "Failed to run write memory command"	
        } else {	
            Write-Output "Configurations are saved on partition: $partition"	
        }	
    }	
}

function GetVMIPs {
    <#		
        .DESCRIPTION	
        Function to get all vThunder instances IP address	
    #>
    $vms = Get-AzVmssVM -ResourceGroupName $resourceGroupName -VMScaleSetName $vThunderScaleSetName
    
    # create array list
    $vThunderIPList = New-Object System.Collections.ArrayList
    
    # get ip address of each vThunder instances
    foreach($vm in $vms){
            # get interface and check public ip address
            $interfaceId = $vm.NetworkProfile.NetworkInterfaces[0].Id
            $interfaceName = $interfaceId.Split('/')[-1]
            $interfaceConfig = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $interfaceName -VirtualMachineScaleSetName $vThunderScaleSetName -VirtualMachineIndex $vm.InstanceId
            $publicIpConfig =  Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -VirtualMachineScaleSetName $vThunderScaleSetName -NetworkInterfaceName $interfaceConfig.name -IpConfigurationName $interfaceConfig.IpConfigurations[0].Name -VirtualMachineIndex $vm.InstanceId
            $vThunderIPAddress = $publicIpConfig.IpAddress
            [void]$vThunderIPList.Add($vThunderIPAddress)
    }
    return $vThunderIPList
}

# check if request for all vthunder password change is true
if ($vThunderProcessingIP) {
    $vthunderbaseUrl = -join("https://", $vThunderProcessingIP, "/axapi/v3")
    $authorizationToken = GetAuthToken -baseUrl $vthunderbaseUrl -vThunderPassword $vThDefaultPassword
    $status = ChangedAdminPassword -baseUrl $vthunderbaseUrl -authorizationToken $authorizationToken -vThunderPassword $vThCurrentPassword
    WriteMemory -baseUrl $vthunderbaseUrl -authorizationToken $authorizationToken

    if ($status -eq 200) {
        Write-Output "Password changed successfully for vThunder $vThunderProcessingIP"
    } else {
        Write-Error "Failed to change password for vThunder $vThunderProcessingIP"
    }
    # If Current password not equal to new password, 
    # then update current password to new password
    # if ($vThCurrentPassword -ne $vThNewPassword) {
    #     Write-Output "Current password is not same as new password, updating new password to current password."
    #     Set-AutomationVariable -Name "vThNewPassword" -Value $vThCurrentPassword.ToString()
    # }
} elseif ($isPasswordChangesForAll -eq "TRUE"){
    # check if current and new password is different
    if($vThCurrentPassword -ne $vThNewPassword){
        # call get vm ips
        $vThunderIPListResponse = GetVMIPs
        # change password of each vThunder instance
        foreach ($vthunderIP in $vThunderIPListResponse) {
            $vthunderbaseUrl = -join("https://", $vthunderIP, "/axapi/v3")
            $authorizationToken = GetAuthToken -baseUrl $vthunderbaseUrl -vThunderPassword $vThCurrentPassword
            $status = ChangedAdminPassword -baseUrl $vthunderbaseUrl -authorizationToken $authorizationToken -vThunderPassword $vThNewPassword
            WriteMemory -baseUrl $vthunderbaseUrl -authorizationToken $authorizationToken
            if ($status -eq 200) {
                Write-Output "Password changed successfully for vThunder $vthunderIP"
            } else {
                Write-Error "Failed to change password for vThunder $vthunderIP"
            }
        }  
    
        # Update current password to new password
        Set-AutomationVariable -Name "vThCurrentPassword" -Value $vThNewPassword.ToString()
        start-sleep -s 10
        $vThCurrentPassword = Get-AutomationVariable -Name vThCurrentPassword

        # Retry to update current password to new password
        if ($vThCurrentPassword -ne $vThNewPassword) {
            $maxRetry = 5
            $currentRetry = 0
            while ($currentRetry -lt $maxRetry) {
                Write-Output "Failed to update current password, retrying..."
                Set-AutomationVariable -Name "vThCurrentPassword" -Value $vThNewPassword.ToString()
                start-sleep -s 10
                $vThCurrentPassword = Get-AutomationVariable -Name vThCurrentPassword
                if ($vThCurrentPassword -eq $vThNewPassword) {
                    Write-Output "Updated current password to new password successfully."
                    # Update flag
                    $isPasswordChangesForAll = 'FALSE'
                    Set-AutomationVariable -Name "vThNewPassApplyFlag" -Value $isPasswordChangesForAll
                    break
                }
                $currentRetry++
            }
        } else {
            Write-Output "Updated current password to new password successfully."
            # Update flag
            $isPasswordChangesForAll = 'FALSE'
            Set-AutomationVariable -Name "vThNewPassApplyFlag" -Value $isPasswordChangesForAll
        }
    }
} else {
        Write-Output "Invalid action, try again..."
}
