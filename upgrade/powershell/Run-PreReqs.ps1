param ($user, $password, $region, $envprefix, $env, $PodId)

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
$webServers = $webServer1, $webServer2

foreach($server in $webServers){
    Invoke-Command -ComputerName $webServer -Credential $Credentials -UseSSL -ScriptBlock {
        $PreReqZip = "D:\installs\WEB\Frontier-Install-PreReqs.zip"
        $location = "D:\installs\WEB\Frontier-Install-PreReqs"
        Write-Host "Installing prerequisites using msi"
        Expand-Archive -Path $PreReqZip -DestinationPath $location
        .\setup.exe
    }
}
Invoke-Command -ComputerName $batServer -Credential $Credentials -UseSSL -ScriptBlock {
    $PreReqZip = "D:\installs\BAT\Frontier-Install-PreReqs.zip"
    $location = "D:\installs\BAT\Frontier-Install-PreReqs"
    Write-Host "Installing prerequisites using msi"
    Expand-Archive -Path $PreReqZip -DestinationPath $location
    .\setup.exe
}