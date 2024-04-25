param (
    [string]$adminUsername,
    [string]$adminPassword,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$spnTenantId,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$azureLocation,
    [string]$stagingStorageAccountName,
    [string]$workspaceName,
    [string]$templateBaseUrl,
    [string]$registerCluster,
    [string]$deployAKSHCI,
    [string]$deployResourceBridge,
    [string]$natDNS,
    [string]$azureusername,
    [string]$azurepassword
    
  
)




$autoDeployClusterResource = "false"
$autoUpgradeClusterResource = "false"
$rdpPort = "3389"

[System.Environment]::SetEnvironmentVariable('azureusername', $azureusername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azurepassword', $azurepassword,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnClientSecret', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnTenantId', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_ID', $spnClientId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_CLIENT_SECRET', $spnClientSecret,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SPN_TENANT_ID', $spnTenantId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('stagingStorageAccountName', $stagingStorageAccountName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('workspaceName', $workspaceName,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployAKSHCI', $deployAKSHCI,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('deployResourceBridge', $deployResourceBridge,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('autoDeployClusterResource', $autoDeployClusterResource,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('autoUpgradeClusterResource', $autoUpgradeClusterResource,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('registerCluster', $registerCluster,[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('natDNS', $natDNS,[System.EnvironmentVariableTarget]::Machine)

#######################################################################
## Setup basic environment
#######################################################################
# Copy PowerShell Profile and Reload
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/PSProfile.ps1") -OutFile $PsHome\Profile.ps1
.$PsHome\Profile.ps1

# Creating HCIBox path
$HCIPath = "C:\HCIBox"
[System.Environment]::SetEnvironmentVariable('HCIBoxDir', $HCIPath,[System.EnvironmentVariableTarget]::Machine)
New-Item -Path $HCIPath -ItemType directory -Force

# Downloading configuration file
$ConfigurationDataFile = "$HCIPath\HCIBox-Config.psd1"
[System.Environment]::SetEnvironmentVariable('HCIBoxConfigFile', $ConfigurationDataFile,[System.EnvironmentVariableTarget]::Machine)
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/HCIBox-Config.psd1") -OutFile $ConfigurationDataFile

# Importing configuration data
$HCIBoxConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

# Create paths
foreach ($path in $HCIBoxConfig.Paths.GetEnumerator()) {
    Write-Output "Creating path $($path.Value)"
    New-Item -Path $path.Value -ItemType directory -Force | Out-Null
}

# Begin transcript
Start-Transcript -Path "$($HCIBoxConfig.Paths["LogsDir"])\Bootstrap.log"

#################################################################################
## Setup host infrastructure and apps
#################################################################################
# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax


refreshenv

az login -u $azureusername -p $azurepassword  
$spnProviderId=$(az ad sp list --display-name "Microsoft.AzureStackHCI" --output json) | ConvertFrom-Json
$spnProviderId = $spnProviderId.id


az login --service-principal -u $spnClientId -p $spnClientSecret --tenant $spnTenantId 


[System.Environment]::SetEnvironmentVariable('spnProviderId', $spnProviderId,[System.EnvironmentVariableTarget]::Machine)

Write-Host "Downloading Azure Stack HCI configuration scripts"
Invoke-WebRequest "https://raw.githubusercontent.com/Azure/arc_jumpstart_docs/main/img/wallpaper/hcibox_wallpaper_dark.png" -OutFile $HCIPath\wallpaper.png
Invoke-WebRequest https://aka.ms/wacdownload -OutFile "$($HCIBoxConfig.Paths["WACDir"])\WindowsAdminCenter.msi"
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/HCIBoxLogonScript.ps1") -OutFile $HCIPath\HCIBoxLogonScript.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/New-HCIBoxCluster.ps1") -OutFile $HCIPath\New-HCIBoxCluster.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Configure-AKSWorkloadCluster.ps1") -OutFile $HCIPath\Configure-AKSWorkloadCluster.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Configure-VMLogicalNetwork.ps1") -OutFile $HCIPath\Configure-VMLogicalNetwork.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Generate-ARM-Template.ps1") -OutFile $HCIPath\Generate-ARM-Template.ps1
Invoke-WebRequest ($templateBaseUrl + "artifacts/LogInstructions.txt") -OutFile $HCIBoxConfig.Paths["LogsDir"]\LogInstructions.txt
Invoke-WebRequest ($templateBaseUrl + "artifacts/jumpstart-user-secret.yaml") -OutFile $HCIPath\jumpstart-user-secret.yaml
Invoke-WebRequest ($templateBaseUrl + "artifacts/hci.json") -OutFile $HCIPath\hci.json
Invoke-WebRequest ($templateBaseUrl + "artifacts/hci.parameters.json") -OutFile $HCIPath\hci.parameters.json

# Replace password and DNS placeholder
Write-Host "Updating config placeholders with injected values."
$adminPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($adminPassword))
(Get-Content -Path $HCIPath\HCIBox-Config.psd1) -replace '%staging-password%',$adminPassword | Set-Content -Path $HCIPath\HCIBox-Config.psd1
(Get-Content -Path $HCIPath\HCIBox-Config.psd1) -replace '%staging-natDNS%',$natDNS | Set-Content -Path $HCIPath\HCIBox-Config.psd1

# Configuring CredSSP and WinRM
Write-Host "Enabling CredSSP."
Enable-WSManCredSSP -Role Server -Force | Out-Null
Enable-WSManCredSSP -Role Client -DelegateComputer $Env:COMPUTERNAME -Force | Out-Null

# Creating scheduled task for HCIBoxLogonScript.ps1
Write-Host "Creating scheduled task for HCIBoxLogonScript.ps1"
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $HCIPath\HCIBoxLogonScript.ps1
Register-ScheduledTask -TaskName "HCIBoxLogonScript" -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel "Highest" -Force

# Clean up Bootstrap.log
Write-Header "Clean up Bootstrap.log."
Stop-Transcript
$logSuppress = Get-Content "$($HCIBoxConfig.Paths.LogsDir)\Bootstrap.log" | Where-Object { $_ -notmatch "Host Application: powershell.exe" }
$logSuppress | Set-Content "$($HCIBoxConfig.Paths.LogsDir)\Bootstrap.log" -Force
