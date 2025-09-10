param ($user, $password, $region, $envprefix, $env, $PodId, $tenants)

$SecurePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $User, $SecurePassword

if ($env -eq 'Prod' -or $env -eq 'Test') {
    $domain = ".cloud.trintech.host"
}
elseif ($env -eq 'Dev') {
    $domain = ".lower.trintech.host"
}
else {
    throw "Selected environment type doesn't exist!"
}

$webServer1 = $region + $envprefix + "DWEB-" + $PodId + "01" + $domain
$webServer2 = $region + $envprefix + "DWEB-" + $PodId + "02" + $domain
$batServer = $region + $envprefix + "TBAT-" + $PodId + "01" + $domain
$sqlServer = $region + $envprefix + "SSQF-" + $PodId + "01" + $domain
$Servers = $webServer1, $webServer2, $batServer

Write-Host "Tenants are : $($tenants)"

foreach($Server in $Servers){
    Invoke-Command -ComputerName $server -Authentication CredSSP -Credential $Credentials -UseSSL -ArgumentList @($tenants,$sqlServer) -ScriptBlock {
        param($tenants,$sqlServer)
function CreateODBCConnectionSQL($server,$database)
{
$regFile = @"
Windows Registry Editor Version 5.00 
[HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources] 
"$database"="ODBC Driver 17 for SQL Server" 
[HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBC.INI\$database] 
"Driver"="C:\\Windows\\system32\\msodbcsql17.dll"
"Server"="$server"
"ClientCertificate"=""
"KeystoreAuthentication"=""
"KeystorePrincipalId"=""
"KeystoreSecret"=""
"KeystoreLocation"=""
"Trusted_Connection"="No"
"Database"="$database"
"Encrypt"="No"
"TrustServerCertificate"="No"
"QuotedId"="No"
"AnsiNPW"="No"
"TransparentNetworkIPResolution"="Disabled"
"@

$regFile | out-file $env:temp\a.reg; 
$regimport =  Start-Process reg -ArgumentList "import $env:temp\a.reg" -PassThru -Wait
    if ($regimport.ExitCode -eq 0)
    {
        Write-Host "Succesffully imported ODBC for $database"
    }

rm $env:temp\a.reg -Force
}
    foreach($tenant in $tenants){
        $DBName = $($tenant) + "_Frontier"
        Write-Host "Recreating ODBC connection for $DBName on $($env:computername)"
        CreateODBCConnectionSQL "$sqlServer" "$DBName"
    }
    }
}