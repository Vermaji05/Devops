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
$sqlServer = $region + $envprefix + "SSQF-" + $PodId + "01" + $domain

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
Write-Host "SQL Hostname: $sqlServer"
Write-Host "Tenants are : $tenants"

$scriptBlock = {
    param($tenants)
    foreach ($tenant in $tenants) {
    Write-Host "Creating SQL backup for $tenant database"
    $frontierDB = $tenant + "_Frontier"
    $frontierSS = "$frontierDB`_Snapshot_" + (Get-Date -Format "yyyyMMddHHmm")
    $workflowDB = $tenant + "_wfl"
    $workflowSS = "$workflowDB`_Snapshot_" + (Get-Date -Format "yyyyMMddHHmm")
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmm"
    $location = "E:\sql_backups\${tenant}"
    $frontierBackup = "${location}\${frontierDB}_${Timestamp}.bak"
    $workflowBackup = "${location}\${workflowDB}_${Timestamp}.bak"
    $snapshotDeletionIntervalHours = 1  #need to set 48
    if (!(Test-Path $location)) {
        New-Item -ItemType Directory -Path $location
    }
    Import-Module SqlServer
    $serverInstance = "."
    #Checking Data location
    $possibleDataLocation = @("D:\SQL_Data\Encrypted","D:\SQL_Data\MSSQL16.MSSQLSERVER\MSSQL\DATA")
    $dataLocation = ''
    $possibleDataLocation | ForEach-Object {
        if ([System.IO.Directory]::Exists($_) -and $dataLocation -eq '')
        {
            $dataLocation = $_
        }
    }

    # Function to create a database snapshot
    function Create-SqlDatabaseSnapshot {
        param (
            [string]$serverInstance,
            [string]$databaseName,
            [string]$snapshotName,
            [string]$snapshotFilePath
        )

        # Use default SQL data file path if no custom path provided
        if (-not $snapshotFilePath) {
            $snapshotFilePath = Get-DefaultDataFilePath -serverInstance $serverInstance
        }

        # Construct snapshot file full path
        $snapshotFile = [System.IO.Path]::Combine($snapshotFilePath, "$snapshotName.ss")

        # Query to create snapshot
        $query = @"
        CREATE DATABASE [$snapshotName] ON
        (
            NAME = $databaseName,
            FILENAME = '$snapshotFile'
        )
        AS SNAPSHOT OF [$databaseName];
"@

        Invoke-Sqlcmd -ServerInstance $serverInstance -TrustServerCertificate -Query $query
        Write-Output "Snapshot '$snapshotName' created successfully at '$snapshotFile'."
    }

    # Function to schedule snapshot deletion
    function Schedule-SnapshotDeletion {
        param (
            [string]$serverInstance,
            [string]$snapshotName,
            [int]$deletionIntervalHours
        )
        
        # Define task action and trigger
        $action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-NoProfile -WindowStyle Hidden -Command `"Import-Module SqlServer; Invoke-Sqlcmd -ServerInstance '$serverInstance' -TrustServerCertificate -Query 'DROP DATABASE [$snapshotName]'`""
        $trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddHours($deletionIntervalHours))
        
        # Register the scheduled task
        $taskName = "DeleteSnapshot_$snapshotName"
        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "Deletes SQL Server snapshot $snapshotName after $deletionIntervalHours hours"
        Write-Output "Scheduled task '$taskName' created to delete snapshot '$snapshotName' in $deletionIntervalHours hours."
    }

    # Step 1: Create the Frontier DB Backup
    Backup-SqlDatabase -ServerInstance $serverInstance -TrustServerCertificate -Database $frontierDB -BackupFile $frontierBackup
    Write-Host "$frontierDB Database backup created successfully."
    # Step 2: Create the Frontier snapshot
    Create-SqlDatabaseSnapshot -serverInstance $serverInstance -databaseName $frontierDB -snapshotName $frontierSS -snapshotFilePath $dataLocation
    Write-Host "$frontierDB Database Snapshot created successfully."
    # Step 3: Schedule the Frontier Snapshot deletion
    Schedule-SnapshotDeletion -serverInstance $serverInstance -snapshotName $frontierSS -deletionIntervalHours $snapshotDeletionIntervalHours
    Write-Host "$frontierSS will be deleted in 48 hours."
    # checking workflow db 
    $sqlCmd = "SELECT CASE WHEN DB_ID('$workflowDB') IS NULL THEN 'FALSE' ELSE 'TRUE' END AS Result;";
    $exists = Invoke-Sqlcmd -ServerInstance $sqlServer -TrustServerCertificate -Query $sqlCmd;
    if($exists.Result -and $exists.Result -eq $true) {
        # Step 1: Create the Frontier DB Backup
        Backup-SqlDatabase -ServerInstance $serverInstance -TrustServerCertificate -Database $workflowDB -BackupFile $workflowBackup
        Write-Host "$workflowDB Database backup created successfully."
        # Step 2: Create the Frontier snapshot
        Create-SqlDatabaseSnapshot -serverInstance $serverInstance -databaseName $workflowDB -snapshotName $workflowSS -snapshotFilePath $dataLocation
        Write-Host "$workflowDB Database Snapshot created successfully."
        # Step 3: Schedule the Frontier Snapshot deletion
        Schedule-SnapshotDeletion -serverInstance $serverInstance -snapshotName $workflowSS -deletionIntervalHours $snapshotDeletionIntervalHours
        Write-Host "$workflowSS will be deleted in 48 hours."
    }
}

}

# Execute the script block on the remote server
Invoke-Command -ComputerName $sqlServer -Credential $Credentials -UseSSL -ScriptBlock $scriptBlock -ArgumentList $tenants