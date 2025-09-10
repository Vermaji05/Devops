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
$webServers = $webServer1, $webServer2

foreach ($webServer in $webServers){
    $tenants = Invoke-Command -ComputerName $webServer -Credential $Credentials -UseSSL -ScriptBlock {
        get-service -DisplayName '*Tomcat*' | ForEach-Object {
            $service = $_
            $name = $service.DisplayName
            $servicelookup = (Get-WmiObject win32_service -filter "Displayname ='$name'")
            $type = $servicelookup.StartMode
            $path = ""
            if ($name -LIKE '*Tomcat*' -and $type -ne 'Disabled') {
                $path = $servicelookup.PathName -replace '"'
                $path = Split-Path $path -Leaf
                $path = $path -replace 'Frontier', ''
                $path = $path -replace '_', ''
                $path        
            } } }
    foreach ($tenant in $tenants) {
        $date = Get-Date -Format "yyyyMMdd"
        $tomcatLocation = "D:\apps\TomcatServers\$tenant"
        $archiveLocation = "D:\apps\TomcatServers\$($tenant)-$($date).zip"
        Write-Host "Taking bakcup $tenant Tomcat. Location: $archiveLocation"
        if(!(Test-Path $archiveLocation)){
            Compress-Archive -Path $tomcatLocation -DestinationPath $archiveLocation
        }else{
            Compress-Archive -Path $tomcatLocation -DestinationPath $archiveLocation -Update
        }
    }
}