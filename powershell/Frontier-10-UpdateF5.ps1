if ((Get-InstalledModule -Name "F5-LTM" -MinimumVersion 1.4.290 -ErrorAction SilentlyContinue) -eq $null) 
{
	$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
	if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -eq $false)
	{
		write-host "Please rerun this script in administrative mode to allow installation of required modules"
		exit
	}
	else
	{
        Set-PSRepository PSGallery -InstallationPolicy Trusted
		Install-Module -Name "F5-LTM" -RequiredVersion 1.4.290
	}
}

$Sitename = '${Common.tenantname}'
$domain = '${Common.Domain}'

$webHostnames = "${frontier.web.servers}".split(",")

$webserverIPs = @()

$webHostnames | foreach{
    write-host "$_.${Common.hostdomain}"
    if ($_ -ne $null -and $_ -ne ''){
        $webserverIPs += [System.Net.Dns]::GetHostAddresses("$_.${Common.hostdomain}").IPAddressToString
    }
}

$LBs = @()
$LBs = "${Common.LB1}","${Common.LB2}"

$LBUserName = "${Common.LBUser}"
$LBPassword = "${Common.LBPassword}"
if('${common.environment}' -eq 'Dev'){
    $LBDomain = "lower.trintech.com"
}else{
    $LBDomain = "frontier.trintech.com"
}
if("${frontier.batch.servers}" -match "AUA2")
{
    $LBDomain = "cadency.trintech.com"
}
$secpasswd = ConvertTo-SecureString $LBPassword -AsPlainText -Force
$LBCreds = New-Object System.Management.Automation.PSCredential $LBUserName, $secpasswd
# write-host "creds:"
# write-host $LBUserName
# write-host $LBPassword
$webPort = "${frontier.httpport}"
$workflowStatus = "${frontier.workflow.enabled}"
$workflowPort = "90"

if ("TrustAllCertsPolicy" -as [type]) {} else {
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
            return true;
        }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
}

#Setup Credential Variables
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $LBUserName,$LBPassword)))

#GetPrimaryDevice
try 
{ 
    $LB1 = $LBs[0]
    write-host $LB1
    Invoke-WebRequest -method GET -Uri "https://$LB1.$LBDomain/mgmt/tm/cm/device/" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -UseBasicParsing
    $resp = Invoke-WebRequest -method GET -Uri "https://$LB1.$LBDomain/mgmt/tm/cm/device/" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -UseBasicParsing
} 
Catch 
{
    write-host $resp
    write-host $_
    write-host $_.Exception
    $error1 = $_.Exception.Message
    $error2 = $_.Exception.Response.GetResponseStream()
    $stream = New-Object System.IO.StreamReader($error2)
    $response = $stream.ReadToEnd()
}

$return = $resp.Content|convertfrom-json
$device1FailoverState = $return.items[0].failoverState
$device2FailoverState = $return.items[1].failoverState

write-host "lb1state: $device1failoverstate"
write-host "lb2state: $device2failoverstate"
if ($device1FailoverState -eq "active")
{
    $primaryLB = $LBs[0]
}
else
{
    $primaryLB = $LBs[1]
}

#Set site name to lower case
$SiteName = $SiteName.tolower()
write-host "sitename: $sitename"
write-host "primaryLB: $PrimaryLB"
#Create F5 Session
new-f5session -LTMCredentials $LBCreds -LTMName "$primaryLB.$LBDomain" -Default
write-host "ltmname: $primaryLB"


#Delete old pools
if($workflowStatus -eq 'True'){
    if($(get-pool).Name.Contains("POOL-$($SiteName)-workflow")){
                write-host "removing POOL-$($SiteName)-workflow"
                get-pool -name POOL-$($SiteName)-workflow | get-poolmember | foreach{
                    $membername = $_.name
                    get-pool -name POOL-$($SiteName)-workflow | Remove-PoolMember -Name $membername -confirm:$false
                }
                write-host "pool member removed, removing pool"
                get-pool -name POOL-$($SiteName)-workflow | Remove-Pool -Name POOL-$($SiteName)-workflow -confirm:$false >$null 2>&1
    }
}

if($(get-pool).Name.Contains("POOL-$($SiteName)-web")){
            write-host "removing POOL-$($SiteName)-web"
            get-pool -name POOL-$($SiteName)-web | get-poolmember | foreach{
                $membername = $_.name
                get-pool -name POOL-$($SiteName)-web | Remove-PoolMember -Name $membername -confirm:$false
            }
            write-host "pool member removed, removing pool"
            get-pool -name POOL-$($SiteName)-web | Remove-Pool -Name POOL-$($SiteName)-web -confirm:$false >$null 2>&1
}

#Setup Web/Workflow Pool
if (!$(get-pool).Name.Contains("POOL-$($SiteName)-web")){
    New-Pool -LoadBalancingMode round-robin -Partition Common -Name POOL-$($SiteName)-web >$null 2>&1
    Add-PoolMonitor -PoolName POOL-$($SiteName)-web -Partition Common -Name /Common/gateway_icmp >$null 2>&1
    write-host "Created POOL-$($SiteName)-web"
    get-pool -name POOL-$($SiteName)-web 
    $webserverIPs | foreach{
        if($_ -match '.'){
            get-pool -name POOL-$($SiteName)-web |Add-PoolMember -Address $_ -PortNumber $webPort -status Enabled >$null 2>&1
   write-host "POOL member $_ created!"
        }
    }
}else{
    write-host "POOL-$($SiteName)-web already exists!"
}

if($workflowStatus -eq 'True'){
if (!$(get-pool).Name.Contains("POOL-$($SiteName)-workflow")){
    New-Pool -LoadBalancingMode round-robin -Partition Common -Name POOL-$SiteName-workflow >$null 2>&1
    Add-PoolMonitor -PoolName POOL-$($SiteName)-workflow -Partition Common -Name /Common/gateway_icmp >$null 2>&1
    write-host "Created POOL-$SiteName-workflow"
    get-pool -name POOL-$SiteName-workflow 
    $webserverIPs | foreach{
        if($_ -match '.'){
            get-pool -name POOL-$SiteName-workflow |Add-PoolMember -Address $_ -PortNumber $workflowPort -status Enabled >$null 2>&1
   write-host "POOL member $_ created!"
        }
    }
}else{
    write-host "POOL-$($SiteName)-workflow already exists!"
}
}

$body = @{
"command"="save"
}

invoke-webrequest -method POST -uri "https://$PrimaryLB.$LBDomain/mgmt/tm/sys/config" -Body ($body|ConvertTo-Json) -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo);"content-type"="application/json"} -UseBasicParsing