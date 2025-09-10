param($user,$password,$adminbox)
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
Invoke-Command -ComputerName $server -Authentication CredSSP -Credential $Credentials -UseSSL -ArgumentList @($svcPassword,$adminbox) -ScriptBlock {
param($svcPassword,$adminbox)
$tenant = "${common.tenantname}"
$SQLServer = "${common.sqlserver}.${common.hostdomain}"
$svcAccount = "svc_${common.tenantname}" + "@" + "${common.hostdomain}"
$svcGroup = "Frontier" + "${common.environment}" + "_svc_Accounts" + "@" + "${common.hostdomain}"
$frontierServicePort = "${frontier.webservicesport}"
write-host "Configure Tomcat for $tenant on $($env:computername) box"
$installDir = "D:\apps\TomcatServers\$tenant"
if (!$(Test-Path $installDir))
{
    mkdir $installDir
}
$value = @"
JavaHome=${common.jdkhome}
TomcatServiceDefaultName=$($tenant)_Frontier
TomcatServiceName=$($tenant)_Frontier
TomcatMenuEntriesEnable=false
TomcatShortcutAllUsers=false
"@
New-Item -Path "$installDir" -Name config.ini -Value $value -Force
$config = "$installDir\config.ini"
if (!$(Test-Path "D:\installs\WEB\apache-tomcat-10.1.18.exe"))
{   
    mkdir -p D:\installs\WEB
    Copy-Item "\\$env:userdnsdomain\netlogon\cloud_files\Frontier\Frontier_Release\2024_2\Frontier Install Packages\WEB\apache-tomcat-10.1.18.exe" "D:\installs\WEB\apache-tomcat-10.1.18.exe"
}
if(!(Get-Service -Name "$($tenant)_Frontier" -ErrorAction Ignore)){
cmd /c "`"D:\installs\WEB\apache-tomcat-10.1.18.exe`" /S /C=$config /D=$installDir"
Start-Sleep 30
Write-Host "Copying config xml into tenant tomcat directory"
$configFiles = 'server.xml', 'web.xml', 'context.xml'
foreach($_ in $configFiles){
Copy-Item "${common.configurations}/$_" "$installDir\conf" -Force }

Write-Host "Create Tomcat Service for $tenant"
Set-Service "$($tenant)_Frontier" -DisplayName "Frontier Tomcat ($($tenant)_Frontier)" -StartupType Automatic
sc.exe config "$($tenant)_Frontier" start=delayed-auto depend="FrontierApplication_$($tenant)" obj="$svcAccount" password="$svcPassword"
}

$file = "$installDir\conf\web.xml"
[xml]$xml = gc $file -Raw
 
[xml]$newNode = @"
<cookie-config>
<http-only>true</http-only>
<secure>true</secure>
</cookie-config>	
"@
 
Write-Host "Setting session timetout to 120"
$xml.'web-app'.'session-config'.'session-timeout' = '120'
 
Write-Host "Adding cookie-config node if it doesn't exist"
if ($xml.'web-app'.'session-config'.'cookie-config' -eq "" -or $xml.'web-app'.'session-config'.'cookie-config' -eq $null)
{
    $xml.'web-app'.'session-config'.AppendChild($xml.ImportNode($newNode.'cookie-config', $true))
    $xml.Save($file)
}

$newacl = Get-Acl -Path "$installDir"
$fileSystemAccessRule = [System.Security.AccessControl.FileSystemAccessRule]::new($svcAccount,'Modify','ContainerInherit,ObjectInherit','None','Allow')
$newacl.SetAccessRule($fileSystemAccessRule)
Set-Acl -Path "$installDir" -AclObject $newacl

Write-Host "Updating JVM Settings"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\$tenant`_Frontier\Parameters\Java" -Name "JvmMs" -Value "256"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\$tenant`_Frontier\Parameters\Java" -Name "JvmMx" -Value "1024"

netsh http add urlacl url=http://+:$frontierServicePort/ user=$svcGroup

}
}
}