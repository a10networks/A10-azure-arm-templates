<#
.Description
    Script for applying vThunder configuration.
	1. SLB
	2. GLM
	3. SSL
	4. Revoke GLM License.
	5. Acos Event
	6. Log Matrice
#>

param (
    [Parameter(Mandatory=$false)]
    [object] $WebhookData
)

$Payload = $WebhookData.RequestBody | ConvertTo-Json -Depth 6
$Payload = $Payload.ToString().replace('\"', '"')
$Payload = $Payload.replace('"{', '{')
$Payload = $Payload.replace('}"', '}')
$Payload = $Payload | ConvertFrom-Json


# Wait till vThunder is Up.
start-sleep -s 180

# Get the resource config from variables
$azureAutoScaleResources = Get-AutomationVariable -Name azureAutoScaleResources
$azureAutoScaleResources = $azureAutoScaleResources | ConvertFrom-Json

if ($null -eq $azureAutoScaleResources) {
    Write-Error "azureAutoScaleResources data is missing." -ErrorAction Stop
}

# Get variables value
$automationAccountName = $azureAutoScaleResources.automationAccountName
$resourceGroupName = $azureAutoScaleResources.resourceGroupName
$vThunderScaleSetName = $azureAutoScaleResources.vThunderScaleSetName

# Authenticate with Azure Portal
$appId = $azureAutoScaleResources.appId
$secret = Get-AutomationVariable -Name clientSecret
$tenantId = $azureAutoScaleResources.tenantId

$secureStringPwd = $secret | ConvertTo-SecureString -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appId, $secureStringPwd
$connectResponse = Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId

if ($null -eq $connectResponse) {
	Write-Output "Failed to connect Azure Portal, retrying..."
	# Authenticate with Azure Portal
	$appId = $azureAutoScaleResources.appId
	$secret = Get-AutomationVariable -Name clientSecret
	$tenantId = $azureAutoScaleResources.tenantId

	$secureStringPwd = $secret | ConvertTo-SecureString -AsPlainText -Force
	$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appId, $secureStringPwd
	$connectResponse = Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId

	if ($null -eq $connectResponse) {
		Write-Error "Failed to connect Azure Portal" -ErrorAction Stop
	}
}

# Defining running IP object
$vThunderRunningIp =  @{}
$vThunderProcessedIPStr = Get-AutomationVariable -Name vThunderIP
$agentPrivateIP = Get-AutomationVariable -Name agentPrivateIP
$vThNewPassword = Get-AutomationVariable -Name vThNewPassword

function deserializer {
    param (
        $stringValue
    )
    $hashTable = @{}
    $splitValue = $stringValue.Split(";")
    foreach($keyValue in $splitValue[0..($splitValue.Length-2)]){
        $keyValue = $keyValue.Trim()
        $keyValue = $keyValue.Split("=")
        if ($null -eq $keyValue[0] -or "" -eq $keyValue[0]){
            continue
        }
        $hashTable.Add($keyValue[0],$keyValue[1])
    }
    return $hashTable
}

$vThunderProcessedIP = deserializer -stringValue $vThunderProcessedIPStr

# Get list of vm from vmss
$vms = Get-AzVmssVM -ResourceGroupName $resourceGroupName -VMScaleSetName $vThunderScaleSetName

# Get public ip address of each vm
foreach($vm in $vms){
	# get interface and check public ip address
	$interfaceId = $vm.NetworkProfile.NetworkInterfaces[0].Id
	$interfaceName = $interfaceId.Split('/')[-1]

	$interfaceConfig = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $interfaceName -VirtualMachineScaleSetName $vThunderScaleSetName -VirtualMachineIndex $vm.InstanceId

	$publicIpConfig =  Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -VirtualMachineScaleSetName $vThunderScaleSetName -NetworkInterfaceName $interfaceConfig.name -IpConfigurationName $interfaceConfig.IpConfigurations[0].Name -VirtualMachineIndex $vm.InstanceId
	$vThunderIPAddress = $publicIpConfig.IpAddress
	# check for public ip excepetion
	if($vThunderIPAddress -eq "Not Assigned"){
		continue
	}

	# Check if vThunder is autoscaling
	if (($Payload.operation -eq "Scale Out") -and ($Payload.context.resourceName -eq $vThunderScaleSetName)) {
		# if public ip is not present in last running public ip list than apply vThunder config
		if (-Not $vThunderProcessedIP.ContainsKey($vThunderIPAddress)){
			Write-Output $vThunderIPAddress "Configuring vthunders instances"
			$changePasswordParams = @{"vThunderProcessingIP"= $vThunderIPAddress}
			Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name "Change-Password-Config" -ResourceGroupName $resourceGroupName -Parameters $changePasswordParams -Wait

			$slbParams = @{"UpdateOnlyServers"=$false; "vThunderProcessingIP"= $vThunderIPAddress}
			$sslGlmParams = @{"vThunderProcessingIP"= $vThunderIPAddress}
			$acosEventParams = @{"vThunderProcessingIP"= $vThunderIPAddress; "agentPrivateIP"= $agentPrivateIP}
			Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name "SLB-Config" -ResourceGroupName $resourceGroupName -Parameters $slbParams
			Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name "SSL-Config" -ResourceGroupName $resourceGroupName -Parameters $sslGlmParams
			Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name "Event-Config" -ResourceGroupName $resourceGroupName -Parameters $acosEventParams
			$glmJob = Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name "GLM-Config" -ResourceGroupName $resourceGroupName -Parameters $sslGlmParams -Wait
			$uuid =  $glmJob[-1]
			$vThunderRunningIp.Add($vThunderIPAddress, $uuid)
			$vThNewPasswordPlanText = "$vThNewPassword"
			Set-AutomationVariable -Name "vThCurrentPassword" -Value $vThNewPasswordPlanText
		}
	}
	
	# Check if server is autoscaling
	if (($WebhookData.RequestBody.operation -eq "Scale Out") -and ($WebhookData.RequestBody.context.resourceName -eq $serverScaleSetName)) {
		Write-Output "Adding/Deleting servers from existing vthunder instances"
		$slbParams = @{"UpdateOnlyServers"=$true; "vThunderProcessingIP"= $vThunderIPAddress}
		Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name "SLB-Config" -ResourceGroupName $resourceGroupName -Parameters $slbParams
		$vThunderRunningIp.Add($vThunderIPAddress, $vThunderProcessedIP[$vThunderIPAddress])
	}
}

# revoke glm
foreach($oldip in $vThunderProcessedIP.Keys){
    if (-Not $vThunderRunningIp.ContainsKey($oldip)){
		$glmRevokeParams = @{"vThunderRevokeLicenseUUID"= $vThunderProcessedIP[$oldip]}
		Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name "GLM-Revoke-Config" -ResourceGroupName $resourceGroupName -Parameters $glmRevokeParams
    }
}

function serializer {
    param (
        $hashtableValue
    )
    $stringValue = ""
    foreach($key in $hashtableValue.Keys){
        $value = $hashtableValue[$key]
        $stringValue = $stringValue+"$key=$value;"
    }
    return $stringValue
}

$vThunderRunningIpStr = serializer -hashtableValue $vThunderRunningIp
Set-AutomationVariable -Name "vThunderIP" -Value $vThunderRunningIpStr


Set-AutomationVariable -Name "vThNewPassApplyFlag" -Value "False"

Write-Output "Done"