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

$tenants = Invoke-Command -ComputerName $webServer1 -Credential $Credentials -UseSSL -ScriptBlock {
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
Write-Host "Pod : $podname"
Write-Host "WebServers are: $webServers"
Write-Host "Tenants are : $tenants"

foreach ($tenant in $tenants) {
Write-Host "Stopping Services for $tenant."
foreach ($webServer in $webServers){
Invoke-Command -ComputerName $webServer -Credential $Credentials -UseSSL -ArgumentList $tenant -ScriptBlock {
param($tenant)
$displayNames = "Frontier Tomcat ($($tenant)_Frontier)", "FrontierApplication_$($tenant)", "FrontierNaming_$($tenant)", "FrontierWF_$($tenant)", "FrontierAPI_$($tenant)"
foreach ($displayName in $displayNames){
    Write-Host "Stopping $displayName on"$($env:computername)
    Stop-Service -DisplayName $displayName -Force -ErrorAction Ignore
}
}
}
Invoke-Command -ComputerName $batServer -Credential $Credentials -UseSSL -ArgumentList $tenant -ScriptBlock {
    param($tenant)
    $displayName = "FrontierScheduler_$($tenant)"
    Write-Host "Stopping $displayName on"$($env:computername)
    Stop-Service -DisplayName $displayName -Force -ErrorAction Ignore
    }
}