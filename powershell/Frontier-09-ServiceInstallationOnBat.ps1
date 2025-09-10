param($user,$password)
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
try {
    write-host "$ScriptDirectory\shared_functions.ps1"
    . ("$ScriptDirectory\shared_functions.ps1")
    
}catch{
    write-host "Import of shared_functions.ps1 failed!"
}

$SecurePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $User, $SecurePassword

$secretname = "${common.tenantname}-configinfo-svcpwd"
$secret = GetSecret $secretname
Set-Location d:\jdk17.0.10_7\bin\
$svcPassword = ./java.exe FrontierEnc dec $secret

"${frontier.batch.servers}".split(",")  | ForEach-Object{
    $server = "$($_.Trim()).$($env:userdnsdomain)"
if ($server -ne '' -and $server -ne $null -and $server -ne ".$env:userdnsdomain"){
Invoke-Command -ComputerName $server -Authentication CredSSP -Credential $Credentials -UseSSL -ArgumentList $svcPassword -ScriptBlock {
param($svcPassword)
$tenant = "${common.tenantname}"
$svcAccount = "svc_${common.tenantname}" + "@" + "${common.hostdomain}"

if (!$(Get-Service "FrontierScheduler_$($tenant)" -ErrorAction SilentlyContinue))
{
    Write-Host "Installing FrontierScheduler Service On Batch server"
    sc.exe create "FrontierScheduler_$($tenant)" binpath="D:\apps\Frontier\Rpswin\admin.exe -config \`"${common.configurations}\FrontierConfig.xml\`" -startupTag=SchedulerAWSStartup /s" start=delayed-auto obj="$svcAccount" DisplayName="FrontierScheduler_$($tenant)" password="$svcPassword"
    Start-Service "FrontierScheduler_$($tenant)"
}
}
}
}