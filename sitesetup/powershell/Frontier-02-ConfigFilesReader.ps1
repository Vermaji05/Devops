param ($user, $password, $region, $envprefix, $env, $PodId, $configLocation, $portaldbserver, $workspacedb, $SMTPPort, $lb1, $lb2)
if (!$(Get-Module -Name powershell-yaml -ListAvailable)) {
    Install-Module powershell-yaml -RequiredVersion 0.4.3 -Scope CurrentUser -Force
}
Import-Module powershell-yaml -Force

$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
try {
    write-host "$ScriptDirectory\shared_functions.ps1"
    . ("$ScriptDirectory\shared_functions.ps1")
    
}
catch {
    write-host "Import of shared_functions.ps1 failed!"
}

$SecurePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $User, $SecurePassword

#Setting up the domain, CMDB hostname and environment prefix per environment
if ($env -eq 'Prod' -or $env -eq 'Test') {
    $domain = ".cloud.trintech.host"
    $domainshort = "cloud"
    $share = "ttw$"
    $rootshare = ""
    $usershare = "User"
    $adminshare = "Admin"
}
elseif ($env -eq 'Dev') {
    $domain = ".lower.trintech.host"
    $domainshort = "lower"
    $share = "Tenant Shares"
    $rootshare = ""
    $usershare = "User"
    $adminshare = "Admin"
}
else {
    throw "Selected environment type doesn't exist!"
}
#setting smtp host
if($env -eq 'Prod'){
$smtphost = "smtp.cadency.host"
}elseif($env -eq 'Test'){
$smtphost = "testsmtp.cadency.host"
}elseif ($env -eq 'Dev'){
$smtphost = "smtp.lower.trintech.host"
}
#setting update hostnames for web, bat and file servers
$webServer1 = $region + $envprefix + "DWEB-" + $PodId + "01"
$webServer2 = $region + $envprefix + "DWEB-" + $PodId + "02"
$batserver = $region + $envprefix + "TBAT-" + $PodId + "01"
#Setting fileserver to dfs share
if($env -eq 'Dev'){
    $fileserver = "USR2LFDSSH-ZZ01"
}else{
$fileserver = $region + $envprefix + "TDFS-ZZ00"
}
Write-host "Web server hostname: $webServer1 and $webServer2"
Write-host "Fileserver hostname: $fileServer"

#Fetching Tenant names as per tomcat services on the web box
$tenants = Invoke-Command -ComputerName $webServer1$domain -Credential $Credentials -UseSSL -ScriptBlock {
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
    #fetching fileserver config path
    $fileServerPath = Invoke-Command -ComputerName $webServer1$domain -Credential $Credentials -ArgumentList $tenant -UseSSL -ScriptBlock {
        param ($tenant)
        $displayName = "FrontierNaming_$tenant"
        if (!(Get-Service -Name $displayName -ErrorAction Ignore)) {
            $displayName = "Frontier Naming Service (Frontier_$tenant)"
        }
        $servicelookup = (Get-WmiObject win32_service -filter "Displayname ='$displayName'")
        $path = $servicelookup.PathName -replace '"'
        $path = $path -Split '-config ' -replace ' -service'
        $path[1] -replace 'FrontierConfig.xml'
    }
    if ($null -eq $fileServerPath -or $fileServerPath -eq '' -or $fileServerPath -eq ' ') {
        Write-Host "Fileserver path is null"
        continue
    }


    #Checking if workflow is enabled
    $wfStatus = Invoke-Command -ComputerName $webServer1$domain -Credential $Credentials -ArgumentList $tenant -UseSSL -ScriptBlock {
        param ($tenant)
        $displayName = "FrontierWF_$tenant"
        if ((Get-Service -Name $displayName -ErrorAction Ignore)) {
            Write-Output "True"
        }else{
            Write-Output "False"
        }
    }

    #Reading appsettings.json file
    if (Test-Path "$fileServerPath\appsettings.json") {
        $appsettings = Get-Content "$fileServerPath\appsettings.json" | ConvertFrom-Json
        $API_PORT = $appsettings.AppEnvironment.Port
        $API_DB_CONNECTION = $appsettings.Database.ConnectionString
    }

    #Reading FrontierConfig.xml file
    if (Test-Path "$fileServerPath/FrontierConfig.xml") {
        $frontierConfig = [xml](Get-Content "$fileServerPath/FrontierConfig.xml")
        $NAMING_PORT = $frontierConfig.Config.General.Naming_Port
        $FRONTIER_SERVICES_PORT = $frontierConfig.Config.General.WEB_SERVICES_PORT
        $DATABASE_SERVER = (($frontierConfig.Config.General.DATABASE_SERVER -split '\.')[0]).ToUpper()
    }

    #Reading frontier-workflow.properties file
    if (Test-Path "$fileServerPath\frontier-workflow.properties") {
        $workflowProperties = Get-Content "$fileServerPath\frontier-workflow.properties"
        $passwordPattern = 'spring\.datasource\.password=ENC\(([^)]+)\)'
        $match = [regex]::Match($workflowProperties, $passwordPattern)
        $WF_DB_PASSWORD = $match.Groups[1].Value
        $WFPortpattern = 'server.port=(\w+)'
        $match = [regex]::Match($workflowProperties, $WFPortpattern)
        $WFPort = $match.Groups[1].Value
        $AJPpattern = 'tomcat.ajp.port=(\w+)'
        $match = [regex]::Match($workflowProperties, $AJPpattern)
        $WFAJPPort = $match.Groups[1].Value
        $apiUserPattern = 'frontier.api.userName=(\w+)'
        $match = [regex]::Match($workflowProperties, $apiUserPattern)
        $apiUsername = $match.Groups[1].Value
        $apiPasswordPattern = 'frontier\.api\.password=ENC\(([^)]+)\)'
        $match = [regex]::Match($workflowProperties, $apiPasswordPattern)
        $apiUserEncPassword = $match.Groups[1].Value
    }

    #Reading frontier.properties file
    if (Test-Path "$fileServerPath\frontier.properties") {
        $frontierProperties = Get-Content "$fileServerPath\frontier.properties"
        $webpassPattern = 'db.password=(\w+)'
        $match = [regex]::Match($frontierProperties, $webpassPattern)
        $WEB_ENC_PASSWORD = $match.Groups[1].Value
    }

    #Fetching Web HTTP Port
    $webHTTPPort = Invoke-Command -ComputerName $webServer1$domain -Credential $Credentials -UseSSL -ArgumentList $tenant -ScriptBlock {
        param ($tenant)
        #fetching tomcat path
        $displayName = "Frontier_$tenant"
        if (!(Get-Service -Name $displayName -ErrorAction Ignore)) {
            $displayName = "$tenant`_Frontier"
        }
        $servicelookup = (Get-WmiObject win32_service -filter "Name ='$displayName'")
        $path = $servicelookup.PathName -replace '"'
        $path = $path -split ' '
        $path = $path[0] -replace("\\bin\\[^\\]+\.exe$", "")
        $path = "$path\conf\server.xml"
        if (Test-Path $path) {
            $xml = [xml](Get-Content $path)
            $xml.Server.Service.Connector.port
        }
    }

    #Fetching WEB Redirect Port
    $webRedirectPort = Invoke-Command -ComputerName $webServer1$domain -Credential $Credentials -UseSSL -ArgumentList $tenant -ScriptBlock {
        param ($tenant)
        #fetching tomcat path
        $displayName = "Frontier_$tenant"
        if (!(Get-Service -Name $displayName -ErrorAction Ignore)) {
            $displayName = "$tenant`_Frontier"
        }
        $servicelookup = (Get-WmiObject win32_service -filter "Name ='$displayName'")
        $path = $servicelookup.PathName -replace '"'
        $path = $path -split ' '
        $path = $path[0] -replace("\\bin\\[^\\]+\.exe$", "")
        $path = "$path\conf\server.xml"
        if (Test-Path $path) {
            $xml = [xml](Get-Content $path)
            $xml.Server.Service.Connector.redirectPort
        }
    }

    Write-Host "Storing secrets into the vault"
    $frontiersecretname = "$tenant-configinfo-frontierdbpwd"
    $frontiersecret = GetSecret $frontiersecretname
    if ($frontiersecret -eq $null -or $frontiersecret -eq '' -or $frontiersecret -eq 1) {
        #secret doesn't exist - check if default exists
        $frontierDBPwd = $WEB_ENC_PASSWORD
        SetSecret "$frontiersecretname" "$frontierDBPwd"
        write-host "Secret $frontiersecretname added!"
    }
    elseif ($frontiersecret -eq -1) {
        write-host "Error in GetSecret"
    }
    else {
        write-host "Secret found!"
        $frontierDBPwd = $frontiersecret
    }
    $apisecretname = "$tenant-configinfo-svcpwd"
    $apisecret = GetSecret $apisecretname
    if ($apisecret -eq $null -or $apisecret -eq '' -or $apisecret -eq 1) {
        #secret doesn't exist - check if default exists
        $apiPwd = $apiUserEncPassword
        SetSecret "$apisecretname" "$apiPwd"
        write-host "Secret $apisecretname added!"
    }
    elseif ($apisecret -eq -1) {
        write-host "Error in GetSecret"
    }
    else {
        write-host "Secret found!"
        $apiPwd = $apisecret
    }
    $api_db_conn_secret = GetSecret "$tenant-configinfo-apidbconnection"
    if ($api_db_conn_secret -eq $null -or $api_db_conn_secret -eq '' -or $api_db_conn_secret -eq 1) {
        #secret doesn't exist - check if default exists
        $apiConn = $API_DB_CONNECTION
        SetSecret "$tenant-configinfo-apidbconnection" "$apiConn"
        write-host "Secret $tenant-configinfo-apidbconnection added!"
    }
    elseif ($apisecret -eq -1) {
        write-host "Error in GetSecret"
    }
    else {
        write-host "Secret found!"
        $apiConn = $api_db_conn_secret
    }

    #Checking SSO Status
    $ssostatus = Read-SqlTableData -ServerInstance $portaldbserver -DatabaseName $workspacedb -SchemaName "dbo" -TableName 'Tenant' | Where-Object { $_.TenantId -eq $tenant }
    if($ssostatus.IsSSO -eq 1){
        $IsSSO = 'True'
    }else{
        $IsSSO = 'False'
    }

    #Fetching license Details
    $query = "SELECT TotalLicenses FROM TenantAssignedApp WHERE TenantId = '$tenant' and AppId = 'FrontAdmin'"
    $licenseCount = $(Invoke-Sqlcmd -ServerInstance $portaldbserver -Database $workspacedb -TrustServerCertificate -Query $query).TotalLicenses

    #Fetching customer domain
    $emailquery = "SELECT STRING_AGG(EmailDomain, ',') AS EmailDomain from EmailDomain where TenantId = '$tenant' AND EmailDomain != '@trintech.com';"
    $emailResult = (Invoke-Sqlcmd -ServerInstance $portaldbserver -Database $workspacedb -TrustServerCertificate  -Query $emailquery).EmailDomain
    if ($emailResult -ne $null -and $emailResult -ne [System.DBNull]::Value) {
    $custDomain = $emailResult.Replace('@', '')
    Write-Output "Email Domain: $custDomain"
    } else {
        Write-Host "No valid EmailDomain found for tenant '$tenant'."
    }

    Write-Host "Creating directory on spring config and copying template files."
    if (!$(test-path "$configLocation/$tenant" )) {
        mkdir -p $configLocation/$tenant
    }
        copy-item -Path "$configLocation/templates/*.yml" -Destination "$configLocation/$tenant" -PassThru  -Recurse -force
        copy-item -Path "$configLocation/templates/$domainshort/*.yml" -Destination "$configLocation/$tenant" -PassThru  -Recurse -force

        #Updating application.yml file
        $appconfigpath = "$configLocation/$tenant/application.yml"
(Get-Content $appconfigpath) | Foreach-Object {
            $_ -replace '<CUSTOMERNAME>', "$tenant" `
                -replace '<ENVIRONMENT>', "$env" `
                -replace '<SMTP>', "$smtphost" `
                -replace '<SMTPPORT>', "$SMTPPort" `
                -replace '<SHARE>', "$share" `
                -replace '<ROOTSHARE>', "$rootshare" `
                -replace '<USERSHARE>', "$usershare" `
                -replace '<ADMINSHARE>', "$adminshare" `
                -replace '<SQLSERVERNAME>', "$DATABASE_SERVER" `
                -replace '<FILESERVER>', "$fileserver" `
                -replace '<DOMAINSHORT>', "$domainshort" `
                -replace '<CUSTOMERDOMAIN>', "$custDomain" `
                -replace '<LB1>', "$lb1" `
                -replace '<LB2>', "$lb2"
        } | Set-Content $appconfigpath

        #Updating frontier.yml file
        $frontierconfigpath = "$configLocation/$tenant/frontier.yml"
(Get-Content $frontierconfigpath) | Foreach-Object {
            $_ -replace '<NAMINGPORT>', "$NAMING_PORT" `
                -replace '<WEBSERVICEPORT>', "$FRONTIER_SERVICES_PORT" `
                -replace '<TOMCATHTTPPORT>', "$webHTTPPort" `
                -replace '<REDIRECTPORT>', "$webRedirectPort" `
                -replace '<WEBSERVERS>', "$webserver1,$webserver2" `
                -replace '<BATSERVERS>', "$batserver" `
                -replace '<AJPPORT>', "$WFAJPPort" `
                -replace '<HTTPPORT>', "$WFPort" `
                -replace '<APIPORT>', "$API_PORT" `
                -replace '<WFENABLED>', "$wfStatus" `
                -replace '<SSOENABLED>', "$IsSSO" `
                -replace '<LicenseCount>', "$licenseCount"
        } | Set-Content $frontierconfigpath
}