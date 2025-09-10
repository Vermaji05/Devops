param ($user, $password, $region, $envprefix, $env, $PodId, $location, $version)

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

foreach ($webServer in $webServers){
    $frontlocation = $location + "\Frontier.zip"
    Copy-Item -Path $frontlocation -Destination "\\$webServer\d$\installs\Frontier-$version.zip" -Force
    Invoke-Command -ComputerName $webServer -Credential $Credentials -UseSSL -ArgumentList $version -ScriptBlock {
    param($version)
    $BinLocation = "D:\apps\Frontier"
    $date = get-date -Format ddMMyyyy
    Write-Host "Taking backup of existing binaries."
    Rename-Item $BinLocation -NewName "D:\apps\Frontier.Backup.$date"
    if(!(Test-Path $BinLocation)){
        New-Item -ItemType Directory $BinLocation
    }
    Expand-Archive -Path "D:\installs\Frontier-$version.zip" -OutputPath $BinLocation
    }
}

$RPSlocation = $location  + "\RpsWin.zip"
Copy-Item -Path $RPSlocation -Destination "\\$batServer\d$\installs\RpsWin-$version.zip" -Force
Invoke-Command -ComputerName $batServer -Credential $Credentials -UseSSL -ArgumentList $version -ScriptBlock {
    param($version)
    $BinLocation = "D:\apps\Frontier\RpsWin"
    $date = get-date -Format ddMMyyyy
    Write-Host "Taking backup of existing binaries."
    Rename-Item $BinLocation -NewName "D:\apps\Frontier\RpsWin.Backup.$date"
    if(!(Test-Path $BinLocation)){
        New-Item -ItemType Directory $BinLocation
    }
    Expand-Archive -Path "D:\installs\RpsWin-$version.zip" -OutputPath $BinLocation
    }