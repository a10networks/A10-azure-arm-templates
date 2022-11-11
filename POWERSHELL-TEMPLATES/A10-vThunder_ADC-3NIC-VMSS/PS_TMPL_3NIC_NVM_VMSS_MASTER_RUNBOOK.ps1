<#
.Description
    Script for applying vThunder configuration.
	1. SLB
	2. GLM
	3. SSL
	4. Revoke GLM License.
#>

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
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId

# Defining running IP object
$vThunderRunningIp =  @{}
$vThunderProcessedIP = Get-AutomationVariable -Name vThunderIP
$vThunderProcessedIP = $vThunderProcessedIP | ConvertFrom-Json -AsHashtable
$agentPrivateIP = Get-AutomationVariable -Name agentPrivateIP

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

	# if public ip is not present in last running public ip list than apply vThunder config
	if (-Not $vThunderProcessedIP.ContainsKey($vThunderIPAddress)){
		Write-Output $vThunderIPAddress "Configuring vthunders instances"
		$slbParams = @{"UpdateOnlyServers"=$false; "vThunderProcessingIP"= $vThunderIPAddress}
		$sslGlmParams = @{"vThunderProcessingIP"= $vThunderIPAddress}
		$acosEventParams = @{"vThunderProcessingIP"= $vThunderIPAddress; "agentPrivateIP"= $agentPrivateIP}
		$slbJob = Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name "SLB-Config" -ResourceGroupName $resourceGroupName -Parameters $slbParams
		$sslJob = Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name "SSL-Config" -ResourceGroupName $resourceGroupName -Parameters $sslGlmParams
		$acosEventJob = Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name "Event-Config" -ResourceGroupName $resourceGroupName -Parameters $acosEventParams
		$glmJob = Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name "GLM-Config" -ResourceGroupName $resourceGroupName -Parameters $sslGlmParams -Wait
		$uuid =  $glmJob[-1]
		$vThunderRunningIp.Add($vThunderIPAddress, $uuid)
	}
	else{
		Write-Output "Adding/Deleting servers from existing vthunder instances"
		$slbParams = @{"UpdateOnlyServers"=$true; "vThunderProcessingIP"= $vThunderIPAddress}
		$slbJob = Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name "SLB-Config" -ResourceGroupName $resourceGroupName -Parameters $slbParams
		$vThunderRunningIp.Add($vThunderIPAddress, $vThunderProcessedIP[$vThunderIPAddress])
	}
}

# revoke glm
foreach($oldip in $vThunderProcessedIP.Keys){
    if (-Not $vThunderRunningIp.ContainsKey($oldip)){
		$glmRevokeParams = @{"vThunderRevokeLicenseUUID"= $vThunderProcessedIP[$oldip]}
		$glmRevokeJob = Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name "GLM-Revoke-Config" -ResourceGroupName $resourceGroupName -Parameters $glmRevokeParams -Wait
    }
}

# update new running vm ip object to variables
$vThunderRunningIp = $vThunderRunningIp | ConvertTo-Json
$vThunderRunningIp = "$vThunderRunningIp"
Set-AutomationVariable -Name "vThunderIP" -Value $vThunderRunningIp
Write-Output "Done"