param ($user, $password, $region, $envprefix, $env, $PodId, $cmdbserver)

if (!$(Get-Module sqlserver -ListAvailable)) {
    Install-Module sqlserver
}

$SecurePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $User, $SecurePassword

#Setting up the domain, CMDB hostname and environment prefix per environment
if ($env -eq 'Prod' -or $env -eq 'Test') {
    $domain = ".cloud.trintech.host"
}
elseif ($env -eq 'Dev') {
    $domain = ".lower.trintech.host"
}
else {
    throw "Selected environment type doesn't exist!"
}
#Setting up all the required variables
$dbname = "CMDB"
$id = [int]$PodId
$podname = "POD$id"
$table = "$Region" + "_" + "$env" + "_Frontier"
$starting_port = "10010"	
$con = new-object "System.data.sqlclient.SQLconnection"
$con.ConnectionString = ("Data Source=$cmdbserver;Initial Catalog=$dbname;Integrated Security=SSPI")

#setting update hostnames for web and file servers
$webServer = $region + $envprefix + "DWEB-" + $PodId + "01" + $domain


Write-host "Web server hostname: $webServer"

#Fetching Tenant names as per tomcat services on the web box
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

#Updating TenantName as blank which are not present in the Pod
$latestrecords = (invoke-sqlcmd -ServerInstance $cmdbserver -TrustServerCertificate -Database $dbname "SELECT TenantName FROM $table WHERE LastUpdated >= DATEADD(HOUR, -24, GETDATE()) and POD = '$podname'").TenantName
$exclusion = $tenants += $latestrecords
$cust_query = (Read-SqlTableData -ServerInstance $cmdbserver -DatabaseName $dbname -SchemaName "dbo" -TableName $table | Where-Object { $_.POD -eq $podname } | Where-Object { $_.TenantName -NotIn $exclusion } | Where-Object { $_.TenantName -NotLike 'blank' }).TenantName
invoke-sqlcmd -ServerInstance $cmdbserver -TrustServerCertificate -Database $dbname "UPDATE dbo.$table SET TenantName = 'blank' , LastUpdated = NULL WHERE POD = '$podname' and TenantName IN ('$($cust_query -join "','")')"
Write-Host "Tenants are : $tenants"
Write-Host "Pod : $podname"
Write-Host "Table : $table"

#Checking configs for each existing tenant to get the port details
foreach ($tenant in $tenants) {
    Write-Host "Tenant: $tenant"
    #fetching fileserver config path
    $fileServerPath = Invoke-Command -ComputerName $webServer -Credential $Credentials -ArgumentList $tenant -UseSSL -ScriptBlock {
        param ($tenant)
        $displayName = "FrontierNaming_$tenant"
        if (!(Get-Service -Name $displayName -ErrorAction SilentlyContinue)) {
            $displayName = "Frontier Naming Service (Frontier_$tenant)"
    
            if (!(Get-Service -Name $displayName -ErrorAction SilentlyContinue)) {
                $displayName = "Frontier Naming Service (${tenant}_Frontier)"
        
                if (!(Get-Service -Name $displayName -ErrorAction SilentlyContinue)) {
                    Write-Host "Service not found"
                    continue
                }
            }
        }
        Write-Host "Naming Service: $displayName"
        $servicelookup = (Get-WmiObject win32_service -filter "Displayname ='$displayName'")
        $path = $servicelookup.PathName -replace '"'
        $path = $path -Split '-config ' -replace ' -service'
        $path[1] -replace 'FrontierConfig.xml'
    }
    if ($null -eq $fileServerPath -or $fileServerPath -eq '' -or $fileServerPath -eq ' ') {
        Write-Host "Fileserver path is null"
        continue
    }
    #Fetching WEB Tomcat Port
    $webHttpPort = Invoke-Command -ComputerName $webServer -Credential $Credentials -UseSSL -ArgumentList $tenant -ScriptBlock {
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
    if ($null -eq $webHttpPort -or $webHttpPort -eq '' -or $webHttpPort -eq ' ') {
        Write-Host "Web Tomcat Port is null"
        continue
    }
    #Fetching WEB Redirect Port
    $webRedirectPort = Invoke-Command -ComputerName $webServer -Credential $Credentials -UseSSL -ArgumentList $tenant -ScriptBlock {
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
    if ($null -eq $webRedirectPort -or $webRedirectPort -eq '' -or $webRedirectPort -eq ' ') {
        Write-Host "Web redirect Port is null"
        continue
    }
    #Setting file path for config files
    $ConfigXMLPath = $fileServerPath + "FrontierConfig.xml"
    $appsettingsPath = $fileServerPath + "appsettings.json"
    $WFpropertyPath = $fileServerPath + "frontier-workflow.properties"
    #Fetching other Naming, Application Service, API, Workflow HTTP, Workflow AJP ports
    if (Test-Path $ConfigXMLPath) {
        $xml = [xml](Get-Content $ConfigXMLPath)
        $namingPort = $xml.Config.General.Naming_Port
        $AppSVCPort = $xml.Config.General.WEB_SERVICES_PORT
    }
    if ($null -eq $namingPort -or $namingPort -eq '' -or $namingPort -eq ' ') {
        Write-Host "Naming Port is null"
        continue
    }
    if ($null -eq $AppSVCPort -or $AppSVCPort -eq '' -or $AppSVCPort -eq ' ') {
        Write-Host "App Service Port is null"
        continue
    }
    if (Test-Path $appsettingsPath) {
        $json = Get-Content $appsettingsPath | ConvertFrom-JSON
        $APIPort = $json.AppEnvironment.Port
    }
    if ($null -eq $APIPort -or $APIPort -eq '' -or $APIPort -eq ' ') {
        Write-Host "API Port is null"
        continue
    }
    if (Test-Path $WFpropertyPath) {
        $content = Get-Content $WFpropertyPath
        $WFpattern = 'server.port=(\w+)'
        $match = [regex]::Match($content, $WFpattern)
        $WFPort = $match.Groups[1].Value
        $AJPpattern = 'tomcat.ajp.port=(\w+)'
        $match = [regex]::Match($content, $AJPpattern)
        $WFAJPPort = $match.Groups[1].Value
    }
    if ($null -eq $WFPort -or $WFPort -eq '' -or $WFPort -eq ' ') {
        Write-Host "Workflow Tomcat Port is null"
        continue
    }
    if ($null -eq $WFAJPPort -or $WFAJPPort -eq '' -or $WFAJPPort -eq ' ') {
        Write-Host "Workflow AJP Port is null"
        continue
    }
    $con = new-object "System.data.sqlclient.SQLconnection"
    $con.ConnectionString = ("Data Source=$cmdbserver;Initial Catalog=$dbname;Integrated Security=SSPI")
    $exist_detail = Read-SqlTableData -ServerInstance $cmdbserver -DatabaseName $dbname -SchemaName "dbo" -TableName $table | Where-Object { $_.TenantName -eq $tenant } | Where-Object { $_.NamingPort -eq $namingPort } | Where-Object { $_.FrontierSVCPort -eq $AppSVCPort } | Where-Object { $_.API_Port -eq $APIPort } | Where-Object { $_.WF_HTTPPort -eq $WFPort } | Where-Object { $_.WF_AJPPort -eq $WFAJPPort } | Where-Object { $_.Web_HTTPPort -eq $webHttpPort } | Where-Object { $_.Web_RedirectPort -eq $webRedirectPort } | Where-Object {$_.POD -eq $podname}
    $available_row = Read-SqlTableData -ServerInstance $cmdbserver -DatabaseName $dbname -SchemaName "dbo" -TableName $table | Where-Object { $_.TenantName -eq 'blank' } | Where-Object { $_.NamingPort -eq $namingPort } | Where-Object {$_.POD -eq $podname}

    #Checking if the tenant exists in the CMDB
    if ($null -ne $tenant -and $tenant -ne '' -and $tenant -ne ' ') {
        if ($exist_detail.TenantName -eq $tenant) {
            Write-Host "$tenant already exists in the CMDB."
        }
        elseif($available_row.TenantName -eq 'blank'){
            #updating Tenant entries
            Write-Host "Adding $tenant details in the CMDB"
            $con.open()
            $sqlcmd = new-object "System.data.sqlclient.sqlcommand"
            $sqlcmd.connection = $con
            $sqlcmd.CommandText = "UPDATE $table SET TenantName = '$tenant', FrontierSVCPort = '$AppSVCPort', Web_HTTPPort = '$webHttpPort', WF_HTTPPort = '$WFPort', WF_AJPPort = '$WFAJPPort', API_Port = '$APIPort', Web_RedirectPort = '$webRedirectPort', LastUpdated = FORMAT(GETDATE(), 'yyyy-MM-dd HH:mm') WHERE NamingPort = '$namingPort' and POD = '$podname'"
            $sqlcmd.ExecuteNonQuery()
            $con.close()
        }
        else {
            #Adding new Tenant entries
            Write-Host "Adding $tenant details in the CMDB"
            $con.open()
            $sqlcmd = new-object "System.data.sqlclient.sqlcommand"
            $sqlcmd.connection = $con
            $sqlcmd.CommandText = "INSERT INTO $table (POD,TenantName,NamingPort,FrontierSVCPort,Web_HTTPPort,WF_HTTPPort,WF_AJPPort,API_Port,Web_RedirectPort,LastUpdated) values ('$podname','$tenant','$namingPort','$AppSVCPort','$webHttpPort','$WFPort','$WFAJPPort','$APIPort','$webRedirectPort',FORMAT(GETDATE(), 'yyyy-MM-dd HH:mm'))"
            $sqlcmd.ExecuteNonQuery()
            $con.close()
        }
    }
}

#Checking if selected pod is already there in the table
$con = new-object "System.data.sqlclient.SQLconnection"
$con.ConnectionString = ("Data Source=$cmdbserver;Initial Catalog=$dbname;Integrated Security=SSPI")
$podavailibility = Read-SqlTableData -ServerInstance $cmdbserver -DatabaseName $dbname -SchemaName "dbo" -TableName $table | Where-Object { $_.POD -eq $podname }
if ( ($podavailibility.POD -eq $podname) -and ($podavailibility.Count -ge "15")) {
    write-host "$table table has enough entries for $podname"
}
else {
    #Adding blank sites in the pod
    Write-Host "$podname will be added on $table"
    $count = $podavailibility.Count
    while ($count -lt 15) {
        $NamingPort = [decimal]$Starting_Port + 1		
        $SVCPort = [decimal]$Starting_Port + 2		
        $Web_Tomcat_Port = [decimal]$Starting_Port + 3		
        $WF_HTTP_Port = [decimal]$Starting_Port + 4		
        $WF_AJPPort = [decimal]$Starting_Port + 5		
        $API_Port = [decimal]$Starting_Port + 6		
        $Web_RedirectPort = [decimal]$Starting_Port + 7
        $existing_details = "SELECT COUNT(*) FROM $table WHERE POD = '$podname' and NamingPort = '$NamingPort'"
        $result = invoke-sqlcmd -ServerInstance $cmdbserver -TrustServerCertificate -Database $dbname -query $existing_details
        if ($result.Column1 -eq 0) {
            $con.Open()
            $sqlcmd = New-Object System.Data.SQLClient.SQLCommand
            $sqlcmd.Connection = $con
            $sqlcmd.CommandText = "INSERT INTO $table (POD,TenantName,NamingPort,FrontierSVCPort,Web_HTTPPort,WF_HTTPPort,WF_AJPPort,API_Port,Web_RedirectPort,LastUpdated) values ('$podname','blank','$NamingPort','$SVCPort','$Web_Tomcat_Port','$WF_HTTP_Port','$WF_AJPPort','$API_Port','$Web_RedirectPort',NULL)"
            $sqlcmd.ExecuteNonQuery()
            $con.Close()
            $count++
        }
        $starting_port = [decimal]$starting_port + 10
    }
}