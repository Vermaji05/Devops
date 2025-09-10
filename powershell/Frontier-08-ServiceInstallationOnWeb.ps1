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


"${frontier.web.servers}".split(",")  | ForEach-Object{
    $server = "$($_.Trim()).$($env:userdnsdomain)"
if ($server -ne '' -and $server -ne $null -and $server -ne ".$env:userdnsdomain"){
Invoke-Command -ComputerName $server -Authentication CredSSP -Credential $Credentials -UseSSL -ArgumentList $svcPassword -ScriptBlock {
param($svcPassword)
$tenant = "${common.tenantname}"
$svcAccount = "svc_${common.tenantname}" + "@" + "${common.hostdomain}"
##Write-Host "Service Password : $svcPassword"  ##Debug TDB

if (!$(Get-Service "FrontierNaming_$($tenant)" -ErrorAction SilentlyContinue))
{
    Write-Host "Installing FrontierNaming Service On WEB Server"
    sc.exe create "FrontierNaming_$($tenant)" binpath="D:\apps\Frontier\MidTier\FrontierNamingService.exe -config \`"${common.configurations}\FrontierConfig.xml\`" -service" start=delayed-auto obj="$svcAccount" DisplayName="FrontierNaming_$($tenant)" password="$svcPassword"
    Start-Service "FrontierNaming_$($tenant)" -ErrorAction SilentlyContinue
}

if (!$(Get-Service "FrontierApplication_$($tenant)" -ErrorAction SilentlyContinue))
{   
    Write-Host "Installing FrontierApplication Service On WEB Server"
    sc.exe create "FrontierApplication_$($tenant)" binpath="D:\apps\Frontier\MidTier\Frontier.exe -config \`"${common.configurations}\FrontierConfig.xml\`" -service" start=delayed-auto depend="FrontierNaming_$($tenant)" obj="$svcAccount" DisplayName="FrontierApplication_$($tenant)" password="$svcPassword"
    Start-Service "FrontierApplication_$($tenant)" -ErrorAction SilentlyContinue
}


if("${frontier.workflow.enabled}" -eq "True"){
    $httpContent = Get-Content D:\apps\Apache\conf\httpd.conf
    if(!($httpContent -contains "ProxyPass `"/FrontierWF_$($tenant)`" `"ajp://localhost:${frontier.workflow.ajpport}/FrontierWF_$($tenant)`" connectiontimeout=1200 timeout=1200 secret=H$`yerx9#aq")){
    Write-Host "Updating httpd.conf for FrontierWF_$($tenant)"
    Add-Content D:\apps\Apache\conf\httpd.conf "`n`nProxyPass `"/FrontierWF_$($tenant)`" `"ajp://localhost:${frontier.workflow.ajpport}/FrontierWF_$($tenant)`" connectiontimeout=1200 timeout=1200 secret=H$`yerx9#aq"
    Add-Content D:\apps\Apache\conf\httpd.conf "ProxyPassReverse `"/FrontierWF_$($tenant)`" `"ajp://localhost:${frontier.workflow.ajpport}/FrontierWF_$($tenant)`""
    Restart-Service "FrontierApacheProxy" -ErrorAction SilentlyContinue
    }
    if (!$(Get-Service "FrontierAPI_$($tenant)" -ErrorAction SilentlyContinue))
    {
        Write-Host "Installing FrontierAPI Service On WEB Server"
        sc.exe create "FrontierAPI_$($tenant)" binpath="D:\apps\Frontier\FrontierAPI\Frontier.Api.exe \`"${common.configurations}\appsettings.json\`"" start=delayed-auto obj="$svcAccount" DisplayName="FrontierAPI_$($tenant)" password="$svcPassword"
    }
    if (!$(Get-Service "FrontierWF_$($tenant)" -ErrorAction SilentlyContinue))
    {
        Write-Host "Installing Frontier WorkFlow Service On WEB Server"
        D:\apps\Frontier\workflow\FrontierWorkflow.exe install "${common.configurations}\FrontierWorkflow.xml"
        sc.exe config "FrontierWF_$($tenant)" depend="FrontierAPI_$($tenant)" obj="$svcAccount" password="$svcPassword"
    }
    Start-Service "FrontierWF_$($tenant)" -ErrorAction SilentlyContinue
    Start-Service "FrontierAPI_$($tenant)" -ErrorAction SilentlyContinue
}
Write-Host "Starting $($tenant)_Frontier Service"
Start-Service -Name "$($tenant)_Frontier" -ErrorAction SilentlyContinue

}
}
}