@echo off
@cd /d "%~dp0"

set RUNLOG=run.log
set BASEDIR=%CD%
set RETURN=0

rem ******************* Set defaults ******************

set             ROOTOU_PARENTOU=OU=Frontier,OU=PCI,OU=Service_Catalog

set      TENANT_USERS_GROUP_DEF=CN=FrontierTenantUsers,%ROOTOU_PARENTOU%
set FRON_SVC_ACCOUNTS_GROUP_DEF=CN=Frontier_svc_Accounts,OU=Groups,%ROOTOU_PARENTOU%

set                 ROOTOU_NAME=TTWDevTenants
set               TENANT_SHARES=Tenant Shares
set                          DC=DC=lower,DC=trintech,DC=host
set                 FILE_SERVER=usr2lfdssh-zz01.lower.trintech.host

set     TENANT_SERVICE_USER_PWD=TRDev4321#

rem ******************* Read parameters ******************  

set TENANT=%~1
if "%~1"=="" goto USAGE

call :CheckUsage "%~2" "dev qa test prod dev_test" ENVIRONMENT
if not "%errorlevel%"=="1" GOTO USAGE

call :CheckUsage "%~3" "1 0 y n yes no true false" DO_GROUPS
if not "%errorlevel%"=="1" GOTO USAGE

call :CheckUsage "%~4" "1 0 y n yes no true false" DO_FOLDERS
if not "%errorlevel%"=="1" GOTO USAGE

call :CheckUsage "%~5" "1 0 y n yes no true false" DO_PERMISSIONS
if not "%errorlevel%"=="1" GOTO USAGE

if not "%~6"=="" SET TENANT_SERVICE_USER_PWD=%6
set "TENANT_SERVICE_USER_PWD=%TENANT_SERVICE_USER_PWD:""="%"

if not "%~7"=="" SET FILE_SERVER=%~7

rem enabledelayedexpansion should be set after reading the password parameter
@setlocal enabledelayedexpansion 
@Prompt $H

rem ******************* Override environment settings ******************

rem BEGIN the dev test overrides - do not remove
set REMOTE_GROUP_DEF=
if /i "%ENVIRONMENT%"=="dev_test" (
	set                       	 DC=DC=corp,DC=gpo,DC=com
	if "%~7"=="" set 	FILE_SERVER=EC2AMAZ-QM9J57J
	set 		   REMOTE_GROUP_DEF="CN=Remote Desktop Users,CN=Builtin,!DC!"
)
rem END the dev test overrides - do not remove

if /i "%ENVIRONMENT%"=="qa" (
	set                 ROOTOU_NAME=TTWQATenants
) else if /i "%ENVIRONMENT%"=="test" (
	set      TENANT_USERS_GROUP_DEF=CN=FrontierTestTenantUsers,OU=Groups,!ROOTOU_PARENTOU!
	set FRON_SVC_ACCOUNTS_GROUP_DEF=CN=FrontierTest_svc_Accounts,OU=Groups,!ROOTOU_PARENTOU!
	set                 ROOTOU_NAME=TTWTestTenants
	set               TENANT_SHARES=TTW$
	set                          DC=DC=cloud,DC=trintech,DC=host
	if "%~7"=="" set    FILE_SERVER=usr2cftdfs-zz01.cloud.trintech.host
) else if /i "%ENVIRONMENT%"=="prod" (
	set      TENANT_USERS_GROUP_DEF=CN=FrontierProdTenantUsers,OU=Groups,!ROOTOU_PARENTOU!
	set FRON_SVC_ACCOUNTS_GROUP_DEF=CN=FrontierProd_svc_Accounts,OU=Groups,!ROOTOU_PARENTOU!
	set                 ROOTOU_NAME=TTWProdTenants
	set               TENANT_SHARES=TTW$
	set                          DC=DC=cloud,DC=trintech,DC=host
	if "%~7"=="" set    FILE_SERVER=usr1cftdfs-zz01.cloud.trintech.host
) 

rem set ENV_PREFS_POLICY_FILE=C:\Windows\SYSVOL\sysvol\corp.gpo.com\Policies\{48247815-6FCD-4AA1-BA6B-E5D506A39B2F}\User\Preferences\EnvironmentVariables\EnvironmentVariables.xml

rem mode con lines=40
rem mode con cols=140

rem ******************* Environment parameters (PROBABLY SHOULD NOT BE MODIFIED) ******************

rem A non-empty USER_PRODUCT variable must have a leading backslash. 
rem The USER_PRODUCT variable is used in the P-drive definition and must match the USER_PRODUCT env setting in the "Portal User TENANT env variables" GPO (if it's empty in this file, use a single space in the GPO)
rem A non-empty USER_PRODUCT variable is used to create a folder under FS\TENANT_SHARES\TENANT ROOT FOLDER\TENANT USER SHARE folder
set                  USER_PRODUCT=\Frontier

rem A non-empty ADMIN_PRODUCT variable must have a leading backslash. 
rem A non-empty ADMIN_PRODUCT variable is used to create a folder under FS\TENANT_SHARES\TENANT ROOT FOLDER\TENANT ADMIN SHARE folder
set                  ADMIN_PRODUCT=\Frontier

set                       ROOTOU=ou=%ROOTOU_NAME%,%ROOTOU_PARENTOU%
set                TENANTOU_NAME=%TENANT%
set                     TENANTOU=ou=%TENANTOU_NAME%,%ROOTOU%
set                  ROOT_FOLDER=%TENANT%
set                  ADMIN_SHARE=Admin
set                   USER_SHARE=User

set            TENANT_USER_GROUP=%TENANT% User Group
set    TENANT_USERGROUP_MEMBEROF="%TENANT_USERS_GROUP_DEF%,%DC%" %REMOTE_GROUP_DEF%

set         TENANT_SERVICE_GROUP=%TENANT% Service Group
set TENANT_SERVICEGROUP_MEMBEROF="%TENANT_USERS_GROUP_DEF%,%DC%" "%FRON_SVC_ACCOUNTS_GROUP_DEF%,%DC%" %REMOTE_GROUP_DEF%

set             TENANT_LOG_GROUP=%TENANT% Log Group
set     TENANT_LOGGROUP_MEMBEROF="%TENANT_USERS_GROUP_DEF%,%DC%" %REMOTE_GROUP_DEF%

set           TENANT_ADMIN_GROUP=%TENANT% Admin Group
set   TENANT_ADMINGROUP_MEMBEROF="%TENANT_USERS_GROUP_DEF%,%DC%" %REMOTE_GROUP_DEF%

set     TENANT_SUPPORT_USER_NAME=trintech.support
set      TENANT_SUPPORT_USER_UPN=trintech.support@%TENANT%.com
set      TENANT_SUPPORT_USER_PWD=TRDev4321#
set TENANT_SUPPORT_USER_DISPNAME="Trintech Support (%TENANT%)"
set    TENANT_SUPPORT_USER_SAMID=ts#%TENANT%
set TENANT_SUPPORT_USER_MEMBEROF="cn=%TENANT_LOG_GROUP%,%TENANTOU%,%DC%" "cn=%TENANT_USER_GROUP%,%TENANTOU%,%DC%"

set     TENANT_SERVICE_USER_NAME=svc_%TENANT%
set TENANT_SERVICE_USER_DISPNAME="Service User (%TENANT%)"
set TENANT_SERVICE_USER_MEMBEROF="cn=%TENANT_SERVICE_GROUP%,%TENANTOU%,%DC%"

set       TENANT_ADMIN_USER_NAME=fron.admin
set        TENANT_ADMIN_USER_UPN=fron.admin@%TENANT%.com
set        TENANT_ADMIN_USER_PWD=TRDev4321#
set   TENANT_ADMIN_USER_DISPNAME="Frontier Admin (%TENANT%)"
set      TENANT_ADMIN_USER_SAMID=fa#%TENANT%
set   TENANT_ADMIN_USER_MEMBEROF="cn=%TENANT_ADMIN_GROUP%,%TENANTOU%,%DC%"

rem ************** End of environment parameters section *************

rem ************** !!!! Do not touch anything beyond this point !!!! ****************

rem File Server
set FS=\\%FILE_SERVER%

rem Tenant Shares (all tenants live in this share)
set TS=%FS%\%TENANT_SHARES%

rem Tenant Root Folder (this should only contain specific '[Tenant] Admin Share' and '[Tenant] User Share' sub-folders under it)
set TENANT_ROOT_FOLDER=%TS%\%ROOT_FOLDER%

rem Tenant Admin Share (this will contain specific tenant configurations, parameters, properties, logs, report *.ini and *.rpt files, etc.)
set TENANT_ADMIN_SHARE=%TENANT_ROOT_FOLDER%\%ADMIN_SHARE%

rem Tenant User Share (this will be mapped as a specific tenant 'P:' drive and will contain all tenant user files)
set TENANT_USER_SHARE=%TENANT_ROOT_FOLDER%\%USER_SHARE%

set TENANT_USER_PRODUCT=%TENANT_USER_SHARE%%USER_PRODUCT%
set TENANT_ADMIN_PRODUCT=%TENANT_ADMIN_SHARE%%ADMIN_PRODUCT%

rem Template folder and share
set TEMPLATE_ROOT_FOLDER=%TS%\Template Root Folder
set TEMPLATE_ADMIN_SHARE=%TEMPLATE_ROOT_FOLDER%\Template Admin Share
set TEMPLATE_USER_SHARE=%TEMPLATE_ROOT_FOLDER%\Template User Share
set TEMPLATE_USER_PRODUCT=%TEMPLATE_USER_SHARE%%USER_PRODUCT%
set TEMPLATE_ADMIN_PRODUCT=%TEMPLATE_ADMIN_SHARE%%ADMIN_PRODUCT%

echo.
echo ************************************************************************ Script Variables ****************************************************************************************

echo.
echo FS (File Server):              %FS%

echo ROOTOU:                        %ROOTOU%
echo TENANTOU:                      %TENANTOU%
echo TENANT_USERS_GROUP_DEF:        %TENANT_USERS_GROUP_DEF%
echo DC:                            %DC%

echo.
echo TENANT_USER_GROUP:             %TENANT_USER_GROUP%
echo TENANT_USERGROUP_MEMBEROF:     %TENANT_USERGROUP_MEMBEROF%

echo TENANT_LOG_GROUP:              %TENANT_LOG_GROUP%
echo TENANT_LOGGROUP_MEMBEROF:      %TENANT_LOGGROUP_MEMBEROF%

echo TENANT_SERVICE_GROUP:          %TENANT_SERVICE_GROUP%
echo TENANT_SERVICEGROUP_MEMBEROF:  %TENANT_SERVICEGROUP_MEMBEROF%

echo TENANT_ADMIN_GROUP:            %TENANT_ADMIN_GROUP%
echo TENANT_ADMINGROUP_MEMBEROF:    %TENANT_ADMINGROUP_MEMBEROF%

echo.
echo TENANT_SUPPORT_USER_NAME:      %TENANT_SUPPORT_USER_NAME%
echo TENANT_SUPPORT_USER_UPN:       %TENANT_SUPPORT_USER_UPN%
echo TENANT_SUPPORT_USER_DISPNAME:  %TENANT_SUPPORT_USER_DISPNAME%
echo TENANT_SUPPORT_USER_SAMID:     %TENANT_SUPPORT_USER_SAMID%
echo TENANT_SUPPORT_USER_MEMBEROF:  %TENANT_SUPPORT_USER_MEMBEROF%

echo TENANT_SERVICE_USER_NAME:      %TENANT_SERVICE_USER_NAME%
echo TENANT_SERVICE_USER_DISPNAME:  %TENANT_SERVICE_USER_DISPNAME%
echo TENANT_SERVICE_USER_MEMBEROF:  %TENANT_SERVICE_USER_MEMBEROF%

echo TENANT_ADMIN_USER_NAME:        %TENANT_ADMIN_USER_NAME%
echo TENANT_ADMIN_USER_UPN:         %TENANT_ADMIN_USER_UPN%
echo TENANT_ADMIN_USER_DISPNAME:    %TENANT_ADMIN_USER_DISPNAME%
echo TENANT_ADMIN_USER_SAMID:       %TENANT_ADMIN_USER_SAMID%
echo TENANT_ADMIN_USER_MEMBEROF:    %TENANT_ADMIN_USER_MEMBEROF%

echo.
echo TS (Tenant Shares):            %TS%
echo TENANT_ROOT_FOLDER:            %TENANT_ROOT_FOLDER%
echo TENANT_ADMIN_SHARE:            %TENANT_ADMIN_SHARE%
echo TENANT_USER_SHARE:             %TENANT_USER_SHARE%
echo TENANT_ADMIN_PRODUCT:          %TENANT_ADMIN_PRODUCT%
echo TENANT_USER_PRODUCT (P-Drive): %TENANT_USER_PRODUCT%

echo.
echo TEMPLATE_ROOT_FOLDER:          %TEMPLATE_ROOT_FOLDER%
echo TEMPLATE_ADMIN_SHARE:          %TEMPLATE_ADMIN_SHARE%
echo TEMPLATE_USER_SHARE:           %TEMPLATE_USER_SHARE%
echo TEMPLATE_ADMIN_PRODUCT:        %TEMPLATE_ADMIN_PRODUCT%
echo TEMPLATE_USER_PRODUCT):        %TEMPLATE_USER_PRODUCT%

:USERS
if not "%DO_GROUPS%"=="1" GOTO FOLDERS

echo.
echo ****************************************************************** Create user groups and roles **********************************************************************************

:ROOTOU
echo.
echo Creating the root tenant's OU (if it does not exist)...

rem verify that the root OU does not exist
echo dsquery ou "%ROOTOU%,%DC%"
dsquery ou "%ROOTOU%,%DC%"                                                                                                                  >>%RUNLOG%
if "%errorlevel%" == "0" goto TENANTOU
rem add the root OU
echo dsadd ou "%ROOTOU%,%DC%"
dsadd ou "%ROOTOU%,%DC%"                                                                                                                    >>%RUNLOG%
if not "%errorlevel%" == "0" goto ERROR

:TENANTOU
echo.
echo Creating the '%TENANT%' OU (if it does not exist)...

rem verify that the tenant's OU does not exist
echo dsquery ou "%TENANTOU%,%DC%"
dsquery ou "%TENANTOU%,%DC%"                                                                                                                >>%RUNLOG%
if "%errorlevel%" == "0" goto GROUP1
rem add the tenant's OU
echo dsadd ou "%TENANTOU%,%DC%"
dsadd ou "%TENANTOU%,%DC%"                                                                                                                  >>%RUNLOG%
if not "%errorlevel%" == "0" goto ERROR

:GROUP1
set GROUP=%TENANT_USER_GROUP%
set MEMBEROF=%TENANT_USERGROUP_MEMBEROF%
set DESC=Tenant user accounts for %TENANT%
rem verify that the group does not exist
echo.
echo Creating "%GROUP%" (if it does not exist)...
echo dsquery group "cn=%GROUP%,%TENANTOU%,%DC%"
dsquery group "cn=%GROUP%,%TENANTOU%,%DC%"                                                                                                  >>%RUNLOG%
if "%errorlevel%" == "0" goto GROUP2
rem add the new group
echo dsadd group "cn=%GROUP%,%TENANTOU%,%DC%" -memberof %MEMBEROF% -desc "%DESC%"
dsadd group "cn=%GROUP%,%TENANTOU%,%DC%" -memberof %MEMBEROF% -desc "%DESC%"                                                                >>%RUNLOG%
if not "%errorlevel%" == "0" goto ERROR

:GROUP2
set GROUP=%TENANT_SERVICE_GROUP%
set MEMBEROF=%TENANT_SERVICEGROUP_MEMBEROF%
set DESC=Tenant service accounts for %TENANT%
rem verify that the group does not exist
echo.
echo Creating "%GROUP%" (if it does not exist)...
echo dsquery group "cn=%GROUP%,%TENANTOU%,%DC%"
dsquery group "cn=%GROUP%,%TENANTOU%,%DC%"                                                                                                  >>%RUNLOG%
if "%errorlevel%" == "0" goto GROUP3
rem add the new group
echo dsadd group "cn=%GROUP%,%TENANTOU%,%DC%" -memberof %MEMBEROF% -desc "%DESC%"
dsadd group "cn=%GROUP%,%TENANTOU%,%DC%" -memberof %MEMBEROF% -desc "%DESC%"                                                                >>%RUNLOG%
if not "%errorlevel%" == "0" goto ERROR

:GROUP3
set GROUP=%TENANT_LOG_GROUP%
set MEMBEROF=%TENANT_LOGGROUP_MEMBEROF%
set DESC=Tenant log accounts for %TENANT%
rem verify that the group does not exist
echo.
echo Creating "%GROUP%" (if it does not exist)...
echo dsquery group "cn=%GROUP%,%TENANTOU%,%DC%"
dsquery group "cn=%GROUP%,%TENANTOU%,%DC%"                                                                                                  >>%RUNLOG%
if "%errorlevel%" == "0" goto GROUP4
rem add the new group
echo dsadd group "cn=%GROUP%,%TENANTOU%,%DC%" -memberof %MEMBEROF% -desc "%DESC%"
dsadd group "cn=%GROUP%,%TENANTOU%,%DC%" -memberof %MEMBEROF% -desc "%DESC%"                                                                >>%RUNLOG%
if not "%errorlevel%" == "0" goto ERROR

:GROUP4
set GROUP=%TENANT_ADMIN_GROUP%
set MEMBEROF=%TENANT_ADMINGROUP_MEMBEROF%
set DESC=Tenant administrative accounts for %TENANT%
rem verify that the group does not exist
echo.
echo Creating "%GROUP%" (if it does not exist)...
echo dsquery group "cn=%GROUP%,%TENANTOU%,%DC%"
dsquery group "cn=%GROUP%,%TENANTOU%,%DC%"                                                                                                  >>%RUNLOG%
if "%errorlevel%" == "0" goto USER1
rem add the new group
echo dsadd group "cn=%GROUP%,%TENANTOU%,%DC%" -memberof %MEMBEROF% -desc "%DESC%"
dsadd group "cn=%GROUP%,%TENANTOU%,%DC%" -memberof %MEMBEROF% -desc "%DESC%"                                                                >>%RUNLOG%
if not "%errorlevel%" == "0" goto ERROR

rem create default users
:USER1
set USER_NAME=%TENANT_SUPPORT_USER_NAME%
set USER_UPN=%TENANT_SUPPORT_USER_UPN%
set USER_SAMID=%TENANT_SUPPORT_USER_SAMID%
set USER_DISPNAME=%TENANT_SUPPORT_USER_DISPNAME%
set USER="cn=%TENANT_SUPPORT_USER_UPN%,%TENANTOU%,%DC%"
set USER_DESC=Tenant support account for %TENANT%
set PWD=%TENANT_SUPPORT_USER_PWD%
set MEMBEROF=%TENANT_SUPPORT_USER_MEMBEROF%
rem verify that the user does not exist
echo.
echo Creating "%USER_NAME%" (if it does not exist)...
echo dsquery user %USER%
dsquery user %USER%                                                                                                                         >>%RUNLOG%
if "%errorlevel%" == "0" goto USER2
rem add the new user	
echo dsadd user %USER% -pwd %PWD% -upn %USER_UPN% -disabled no -pwdneverexpires yes -acctexpires never -samid %USER_SAMID% -display %USER_DISPNAME% -memberof %MEMBEROF% -desc "%USER_DESC%"
dsadd user %USER% -pwd %PWD% -upn %USER_UPN% -disabled no -pwdneverexpires yes -acctexpires never -samid %USER_SAMID% -display %USER_DISPNAME% -memberof %MEMBEROF% -desc "%USER_DESC%"                >>%RUNLOG%
if not "%errorlevel%" == "0" goto ERROR

:USER2
set USER_NAME=%TENANT_SERVICE_USER_NAME%
set USER_DISPNAME=%TENANT_SERVICE_USER_DISPNAME%
set USER="cn=%TENANT_SERVICE_USER_NAME%,%TENANTOU%,%DC%"
set USER_DESC=Tenant service account for %TENANT%
set PWD=!TENANT_SERVICE_USER_PWD!
set MEMBEROF=%TENANT_SERVICE_USER_MEMBEROF%
rem verify that the user does not exist
echo.
echo Creating "%USER_NAME%" (if it does not exist)...
echo dsquery user %USER%
dsquery user %USER%                                                                                                                         >>%RUNLOG%
if "%errorlevel%" == "0" goto USER3
rem add the new user
echo dsadd user %USER% -pwd %PWD% -disabled no -pwdneverexpires yes -acctexpires never -display %USER_DISPNAME% -memberof %MEMBEROF% -desc "%USER_DESC%"
dsadd user %USER% -pwd %PWD% -disabled no -pwdneverexpires yes -acctexpires never -display %USER_DISPNAME% -memberof %MEMBEROF% -desc "%USER_DESC%"                >>%RUNLOG%
if not "%errorlevel%" == "0" goto ERROR

:USER3
set USER_NAME=%TENANT_ADMIN_USER_NAME%
set USER_UPN=%TENANT_ADMIN_USER_UPN%
set USER_SAMID=%TENANT_ADMIN_USER_SAMID%
set USER_DISPNAME=%TENANT_ADMIN_USER_DISPNAME%
set USER="cn=%TENANT_ADMIN_USER_UPN%,%TENANTOU%,%DC%"
set USER_DESC=Tenant administrator account for %TENANT%
set PWD=%TENANT_ADMIN_USER_PWD%
set MEMBEROF=%TENANT_ADMIN_USER_MEMBEROF%
rem verify that the user does not exist
echo.
echo Creating "%USER_NAME%" (if it does not exist)...
echo dsquery user %USER%
dsquery user %USER%                                                                                                                         >>%RUNLOG%
if "%errorlevel%" == "0" goto FOLDERS
rem add the new user
echo dsadd user %USER% -pwd %PWD% -upn %USER_UPN% -disabled no -pwdneverexpires yes -acctexpires never -samid %USER_SAMID% -display %USER_DISPNAME% -memberof %MEMBEROF% -desc "%USER_DESC%"
dsadd user %USER% -pwd %PWD% -upn %USER_UPN% -disabled no -pwdneverexpires yes -acctexpires never -samid %USER_SAMID% -display %USER_DISPNAME% -memberof %MEMBEROF% -desc "%USER_DESC%"                >>%RUNLOG%
if not "%errorlevel%" == "0" goto ERROR

:FOLDERS
set fmt="[-47] [30][35][60]"
echo.
echo ************************************************************************* Folder Structure ***************************************************************************************
echo (Note: the folder structure below will be created directly under "%TS%" share which should grant "Read" NTFS permissions to "FrontierTenantUsers" and "Full Control" permission on the share)
echo.
call :Format %fmt% "[Tenant] ...................................1a)" "Reset permissions to the defau" "lts and apply to all child sub-fold" "ers: /T /Q /C /RESET" 
call :Format %fmt% "                                        1b)" "%TENANT_USER_GROUP%"    "- grant 'Read & Traverse'"       "to 'This folder only, enable inheritance'"
call :Format %fmt% "                                        1c)" "%TENANT_SERVICE_GROUP%" "- grant 'Modify'"                "to 'This folder, subfolders and files'"
call :Format %fmt% "                                        1d)" "%TENANT_ADMIN_GROUP%"   "- grant 'Read, Write'"     		"to 'This folder, subfolders and files'"
call :Format %fmt% "                                        1e)" "%TENANT_ADMIN_GROUP%"   "- grant 'Traverse'"        		"to 'This folder and subfolders'"
call :Format %fmt% "User ...................................2a)" "%TENANT_ADMIN_GROUP%"   "- grant 'Modify'"                "to 'This folder, subfolders and files'"
call :Format %fmt% "                                        2b)" "%TENANT_USER_GROUP%"    "- grant 'Read'"                  "to 'This folder, subfolders and files'"
call :Format %fmt% "                                        2c)" "%TENANT_USER_GROUP%"    "- grant 'Traverse'"              "to 'This folder and subfolders'"
                                                                                                                            
if "%USER_PRODUCT%" == "" (                                                                                                 
call :Format %fmt% "                                        2d)" "%TENANT_USER_GROUP%"    "- grant 'Write and Delete'"      "to 'This folder, Subfolders and files'"
) else (                                                                                                                    
call :Format %fmt% "    Frontier............................2d)" "%TENANT_USER_GROUP%"    "- grant 'Write and Delete'"      "to 'This folder, Subfolders and files'"
)                                                                                                                           
                                                                                                                            
call :Format %fmt% "        Client Import....................3)" "%TENANT_USER_GROUP%"    "- deny  'Delete'"                "to 'This folder only'"
call :Format %fmt% "            Static.......................4)" "%TENANT_USER_GROUP%"    "- deny  'Delete'"                "to 'This folder only'"
call :Format %fmt% "        Export Files.....................5)" "%TENANT_USER_GROUP%"    "- deny  'Delete'"                "to 'This folder only'"
call :Format %fmt% "        Misc File........................6)" "%TENANT_USER_GROUP%"    "- deny  'Delete'"                "to 'This folder only'"
call :Format %fmt% "        Processing Results...............7)" "%TENANT_USER_GROUP%"    "- deny  'Delete'"                "to 'This folder only'"
call :Format %fmt% "            Logs........................8a)" "Take ownership of this folder " "before removing inheritance"
call :Format %fmt% "                                        8b)" "%TENANT_LOG_GROUP%"     "- grant 'Modify'"                "to 'This folder, subfolders and files, disable inheritance'"
call :Format %fmt% "                                        8c)" "%TENANT_USER_GROUP%"    "- remove all rights"
call :Format %fmt% "                RDP......................9)" "%TENANT_USER_GROUP%"    "- grant 'Write'"                 "to 'This folder, subfolders and files'"
call :Format %fmt% "                Scheduler.................."
call :Format %fmt% "                WebAccess.................."
call :Format %fmt% "            Recap.........................." "Hide folder, but not files"
call :Format %fmt% "                                       10a)" "Take ownership of this folder " "before removing inheritance"
call :Format %fmt% "                                       10b)" "%TENANT_USER_GROUP%"    "- deny  'Delete'"                "to 'This folder, subfolders and files, disable inheritance'"
call :Format %fmt% "                                       10c)" "%TENANT_USER_GROUP%"    "- remove all granted rights"
call :Format %fmt% "                                       10d)" "%TENANT_USER_GROUP%"    "- grant 'Read, Write'" 			"to 'This folder, subfolders and files'"
call :Format %fmt% "        	User Logs...................11)" "%TENANT_USER_GROUP%"    "- deny  'Delete'"                "to 'This folder only'"
call :Format %fmt% "        Reports.........................12)" "%TENANT_USER_GROUP%"    "- deny  'Delete'"                "to 'This folder only'"
call :Format %fmt% "            Frontier Custom Reports........" "Hide folder, but not files"
call :Format %fmt% "                                       13a)" "Take ownership of this folder " "before removing inheritance"
call :Format %fmt% "                                       13b)" "%TENANT_USER_GROUP%"    "- deny  'Delete'"                "to 'This folder, subfolders and files, disable inheritance'"
call :Format %fmt% "                                       13c)" "%TENANT_USER_GROUP%"    "- remove all granted rights"
call :Format %fmt% "                                       13d)" "%TENANT_USER_GROUP%"    "- grant 'Read'"                  "to 'Subfolders and files'
call :Format %fmt% "                                       13e)" "%TENANT_ADMIN_GROUP%"   "- remove all granted rights"
call :Format %fmt% "                                       13f)" "%TENANT_ADMIN_GROUP%"   "- grant 'Read'"           		"to 'This folder, subfolders and files'"
call :Format %fmt% "            TransferManager.............14)" "%TENANT_USER_GROUP%"    "- deny  'Delete'"                "to 'This folder only'"
call :Format %fmt% "                Log.....................15)" "%TENANT_USER_GROUP%"    "- deny  'Delete'"                "to 'This folder only'"
call :Format %fmt% "        Shared Folder...................16)" "%TENANT_USER_GROUP%"    "- deny  'Delete'"                "to 'This folder only'"
call :Format %fmt% "            Static......................17)" "%TENANT_USER_GROUP%"    "- deny  'Delete'"                "to 'This folder only'"
echo.     
call :Format %fmt% "Admin ....................................." "Hide folder and subfolders, bu" "t not files"
call :Format %fmt% "                                        18)" "%TENANT_ADMIN_GROUP%"   "- deny  'Delete'"                "to 'This folder, subfolders and files'"
call :Format %fmt% "    Frontier                               "
call :Format %fmt% "        Configurations                     "      
call :Format %fmt% "            Public......................19)" "%TENANT_USER_GROUP%"    "- grant 'Read'"                  "to 'This folder, subfolders and files'"
echo.
call :Format %fmt% "Admin ..................................20)" "Hide folder and subfolders, bu" "t not files"
call :Format %fmt% "User\Frontier\Processing Results\Recap....." "Hide folder, but not files"
call :Format %fmt% "Us\Frontier\Reports\Frontier Custom Reports" "Hide folder, but not files"
echo **********************************************************************************************************************************************************************************

if not "%DO_GROUPS%"=="1" (
	if not "%DO_FOLDERS%"=="1" (
		if not "%DO_PERMISSIONS%"=="1" (
			echo.
			echo No actual work is done
			goto END
		)
	)
)

if not "%DO_FOLDERS%"=="1" GOTO PERMISSIONS

echo.                                                                                                         
echo Creating '%TENANT%' tenant folders (if they do not exist)...                                             

@echo on

mkdir "%TENANT_ROOT_FOLDER%"                                                                                                                >>%RUNLOG%

mkdir "%TENANT_USER_SHARE%"                                                                                                                 >>%RUNLOG%
if not "%TENANT_USER_SHARE%" == "%TENANT_USER_PRODUCT%" mkdir "%TENANT_USER_PRODUCT%"                                                       >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Client Import"                                                                                                 >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Client Import\Static"                                                                                          >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Export Files"                                                                                                  >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Misc File"                                                                                                     >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Processing Results"                                                                                            >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Processing Results\Logs"                                                                                       >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Processing Results\Logs\RDP"                                                                                   >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Processing Results\Logs\Scheduler"                                                                             >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Processing Results\Logs\WebAccess"                                                                             >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Processing Results\Recap"                                                                                      >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Processing Results\User Logs"                                                                                  >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Reports"                                                                                                       >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Reports\Frontier Custom Reports"                                                                               >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Reports\TransferManager"                                                                                       >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Reports\TransferManager\Log"                                                                                   >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Shared Folder"                                                                                                 >>%RUNLOG%
mkdir "%TENANT_USER_PRODUCT%\Shared Folder\Static"                                                                                          >>%RUNLOG%

mkdir "%TENANT_ADMIN_SHARE%"                                                                                                                >>%RUNLOG%
if not "%TENANT_ADMIN_SHARE%" == "%TENANT_ADMIN_PRODUCT%" mkdir "%TENANT_ADMIN_PRODUCT%"                                                    >>%RUNLOG%
mkdir "%TENANT_ADMIN_PRODUCT%\Configurations"                                                                                               >>%RUNLOG%
mkdir "%TENANT_ADMIN_PRODUCT%\Configurations\Public"                                                                                        >>%RUNLOG%

@echo off

:PERMISSIONS
if not "%DO_PERMISSIONS%"=="1" GOTO DONE

echo.
echo ************************************************************************** Apply folder security *********************************************************************************

rem icacls scope:
rem <empty>         = This folder only
rem (OI)(CI)        = This folder, subfolders and files
rem (OI)            = This folder and files
rem (CI)            = This folder and subfolders
rem (OI)(IO)        = Files only
rem (CI)(IO)        = Subfolders only
rem (OI)(CI)(IO)    = Subfolders and files only
rem (IO)            = The ACE does not apply to the current file/directory

echo.
echo Assigning security permissions to '%TENANT%' tenant folders...

rem permissions specific to TENANT_ROOT_FOLDER folder and subfolders
SET FOLDER=%TENANT_ROOT_FOLDER%

echo.
echo Saving '%TENANT%' root folder Access Control List (ACL)...
icacls "%FOLDER%" /t /c                                                                                                                                            	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
echo 1a) In "%FOLDER%" - reset permissions to the defaults and apply to all child sub-folders: /T /Q /C /RESET 
echo icacls "%FOLDER%" /T /Q /C /RESET
icacls "%FOLDER%" /T /Q /C /RESET                                                                                                                                  	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
echo 1b) In "%FOLDER%" for "%TENANT_USER_GROUP%" - grant "Read ^& Traverse" to "This folder only", enable inheritance
echo icacls "%FOLDER%" /C /grant "%TENANT_USER_GROUP%":(GR,X) /inheritance:e
icacls "%FOLDER%" /C /grant "%TENANT_USER_GROUP%":(GR,X) /inheritance:e                                                                                            	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
echo 1c) In "%FOLDER%" for "%TENANT_SERVICE_GROUP%" - grant "Modify" to "This folder, subfolders and files"
echo icacls "%FOLDER%" /C /grant "%TENANT_SERVICE_GROUP%":(OI)(CI)(M)
icacls "%FOLDER%" /C /grant "%TENANT_SERVICE_GROUP%":(OI)(CI)(M)                                                                                                   	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
echo 1d) In "%FOLDER%" for "%TENANT_ADMIN_GROUP%" - grant "Read, Write" to "This folder, subfolders and files"
echo icacls "%FOLDER%" /C /grant "%TENANT_ADMIN_GROUP%":(OI)(CI)(GR,GW)
icacls "%FOLDER%" /C /grant "%TENANT_ADMIN_GROUP%":(OI)(CI)(GR,GW)                                                                                                	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
echo 1e) In "%FOLDER%" for "%TENANT_ADMIN_GROUP%" - grant "Traverse" to "This folder and subfolders"
echo icacls "%FOLDER%" /C /grant "%TENANT_ADMIN_GROUP%":(CI)(X)
icacls "%FOLDER%" /C /grant "%TENANT_ADMIN_GROUP%":(CI)(X)    		                                                                                       	       	>>%RUNLOG%

rem permissions specific to TENANT_USER_SHARE folder and subfolders
echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_SHARE%
echo 2a) In "%FOLDER%" for "%TENANT_ADMIN_GROUP%" - grant "Modify" to "This folder, subfolders and files"
echo icacls "%FOLDER%" /C /grant "%TENANT_ADMIN_GROUP%":(OI)(CI)(M)
icacls "%FOLDER%" /C /grant "%TENANT_ADMIN_GROUP%":(OI)(CI)(M)  		                                                                                       	   	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_SHARE%
echo 2b) In "%FOLDER%" for "%TENANT_USER_GROUP%" - grant "Read" to "This folder, subfolders and files"
echo icacls "%FOLDER%" /C /grant "%TENANT_USER_GROUP%":(OI)(CI)(GR)
icacls "%FOLDER%" /C /grant "%TENANT_USER_GROUP%":(OI)(CI)(GR)  		                                                                                       	   	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_SHARE%
echo 2c) In "%FOLDER%" for "%TENANT_USER_GROUP%" - grant "Traverse" to "This folder and subfolders"
echo icacls "%FOLDER%" /C /grant "%TENANT_USER_GROUP%":(CI)(X)
icacls "%FOLDER%" /C /grant "%TENANT_USER_GROUP%":(CI)(X)    		                                                                                       	       	>>%RUNLOG%

if "%USER_PRODUCT%" == "" (
echo **********************************************************************************************************************************************************************************
echo 2d^) In "%TENANT_USER_SHARE%" for "%TENANT_USER_GROUP%" - grant "Write, Delete" to "This folder, subfolders and files"
echo icacls "%TENANT_USER_SHARE%" /C /grant "%TENANT_USER_GROUP%":^(OI^)^(CI^)^(W,DE^)
icacls "%TENANT_USER_SHARE%" /C /grant "%TENANT_USER_GROUP%":^(OI^)^(CI^)^(W,DE^)                                                                                 	>>%RUNLOG%
) else (
echo **********************************************************************************************************************************************************************************
echo 2d^) In "%TENANT_USER_PRODUCT%" for "%TENANT_USER_GROUP%" - grant "Write, Delete" to "This folder, subfolders and files"
echo icacls "%TENANT_USER_PRODUCT%" /C /grant "%TENANT_USER_GROUP%":^(OI^)^(CI^)^(W,DE^)
icacls "%TENANT_USER_PRODUCT%" /C /grant "%TENANT_USER_GROUP%":^(OI^)^(CI^)^(W,DE^)                                                                              	>>%RUNLOG%
)

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Client Import
echo 3) In "%FOLDER%" for "%TENANT_USER_GROUP%" - deny "Delete" to "This folder only"
echo icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)
icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)                                                                                                              	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Client Import\Static
echo 4) In "%FOLDER%" for "%TENANT_USER_GROUP%" - deny "Delete" to "This folder only"
echo icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)
icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)                                                                                                              	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Export Files
echo 5) In "%FOLDER%" for "%TENANT_USER_GROUP%" - deny "Delete" to "This folder only"
echo icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)
icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)                                                                                                              	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Misc File
echo 6) In "%FOLDER%" for "%TENANT_USER_GROUP%" - deny "Delete" to "This folder only"
echo icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)
icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)                                                                                                              	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Processing Results
echo 7) In "%FOLDER%" for "%TENANT_USER_GROUP%" - deny "Delete" to "This folder only"
echo icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)
icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)                                                                                                              	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Processing Results\Logs
echo 8a) Take ownership of "%FOLDER%" before removing inheritance
echo takeown /f "%FOLDER%" /r /d y
takeown /f "%FOLDER%" /r /d y										                   		                                                                    	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Processing Results\Logs
echo 8b) In "%FOLDER%" for "%TENANT_LOG_GROUP%" - grant "Modify" to "This folder, subfolders and files", disable inheritance
echo icacls "%FOLDER%" /C /grant "%TENANT_LOG_GROUP%":(OI)(CI)(M) /inheritance:d
icacls "%FOLDER%" /C /grant "%TENANT_LOG_GROUP%":(OI)(CI)(M) /inheritance:d                                                                                       	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Processing Results\Logs
echo 8c) In "%FOLDER%" for "%TENANT_USER_GROUP%" - remove all rights
echo icacls "%FOLDER%" /C /remove "%TENANT_USER_GROUP%"
icacls "%FOLDER%" /C /remove "%TENANT_USER_GROUP%"        		           	                                                         								>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Processing Results\Logs\RDP
echo 9) In "%FOLDER%" for "%TENANT_USER_GROUP%" - grant "Write" to "This folder, subfolders and files"
echo icacls "%FOLDER%" /C /grant "%TENANT_USER_GROUP%":(OI)(CI)(W)
icacls "%FOLDER%" /C /grant "%TENANT_USER_GROUP%":(OI)(CI)(W)                                                                                                      	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Processing Results\Recap
echo 10a) Take ownership of "%FOLDER%" before removing inheritance
echo takeown /f "%FOLDER%" /r /d y
takeown /f "%FOLDER%" /r /d y										                   		                                                                    	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Processing Results\Recap
echo 10b) In "%FOLDER%" for "%TENANT_USER_GROUP%" - deny "Delete" to "This folder, subfolders and files", disable inheritance 
echo icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(OI)(CI)(DE) /inheritance:d
icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(OI)(CI)(DE) /inheritance:d                                                                                       	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Processing Results\Recap
echo 10c) In "%FOLDER%" for "%TENANT_USER_GROUP%" - remove all granted rights
echo icacls "%FOLDER%" /C /remove:g "%TENANT_USER_GROUP%"
icacls "%FOLDER%" /C /remove:g "%TENANT_USER_GROUP%"        		                                                                    							>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Processing Results\Recap
echo 10d) In "%FOLDER%" for "%TENANT_USER_GROUP%" - grant "Read, Write" to "This folder, subfolders and files"
echo icacls "%FOLDER%" /C /grant "%TENANT_USER_GROUP%":(OI)(CI)(GR,GW)
icacls "%FOLDER%" /C /grant "%TENANT_USER_GROUP%":(OI)(CI)(GR,GW)                                                                                                  	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Processing Results\User Logs
echo 11) In "%FOLDER%" for "%TENANT_USER_GROUP%" - deny "Delete" to "This folder only" 
echo icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)
icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)                                                                                                              	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Reports
echo 12) In "%FOLDER%" for "%TENANT_USER_GROUP%" - deny "Delete" to "This folder only" 
echo icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)
icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)                                                                                                              	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Reports\Frontier Custom Reports
echo 13a) Take ownership of "%FOLDER%" before removing inheritance
echo takeown /f "%FOLDER%" /r /d y
takeown /f "%FOLDER%" /r /d y										                   		                                                                    	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Reports\Frontier Custom Reports
echo 13b) In "%FOLDER%" for "%TENANT_USER_GROUP%" - deny "Delete" to "This folder, subfolders and files", disable inheritance 
echo icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(OI)(CI)(DE) /inheritance:d
icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(OI)(CI)(DE) /inheritance:d                                                                                       	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Reports\Frontier Custom Reports
echo 13c) In "%FOLDER%" for "%TENANT_USER_GROUP%" - remove all granted rights
echo icacls "%FOLDER%" /C /remove:g "%TENANT_USER_GROUP%"
icacls "%FOLDER%" /C /remove:g "%TENANT_USER_GROUP%"        		                                                                    							>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Reports\Frontier Custom Reports
echo 13d) In "%FOLDER%" for "%TENANT_USER_GROUP%" - grant "Read" to "Subfolders and files"
echo icacls "%FOLDER%" /C /grant "%TENANT_USER_GROUP%":(OI)(CI)(IO)(GR)
icacls "%FOLDER%" /C /grant "%TENANT_USER_GROUP%":(OI)(CI)(IO)(GR)				                                                                                   	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Reports\Frontier Custom Reports
echo 13e) In "%FOLDER%" for "%TENANT_ADMIN_GROUP%" - remove all granted rights
echo icacls "%FOLDER%" /C /remove:g "%TENANT_ADMIN_GROUP%"
icacls "%FOLDER%" /C /remove:g "%TENANT_ADMIN_GROUP%"        		                                                                    							>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Reports\Frontier Custom Reports
echo 13f) In "%FOLDER%" for "%TENANT_ADMIN_GROUP%" - grant "Read" to "This folder, subfolders and files"
echo icacls "%FOLDER%" /C /grant "%TENANT_ADMIN_GROUP%":(OI)(CI)(GR)
icacls "%FOLDER%" /C /grant "%TENANT_ADMIN_GROUP%":(OI)(CI)(GR)                                                                                                		>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Reports\TransferManager
echo 14) In "%FOLDER%" for "%TENANT_USER_GROUP%" - deny "Delete" to "This folder only"
echo icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)
icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)                                                                                                              	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Reports\TransferManager\Log
echo 15) In "%FOLDER%" for "%TENANT_USER_GROUP%" - deny "Delete" to "This folder only"
echo icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)
icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)                                                                                                              	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Shared Folder
echo 16) In "%FOLDER%" for "%TENANT_USER_GROUP%" - deny "Delete" to "This folder only"
echo icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)
icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)                                                                                                              	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_USER_PRODUCT%\Shared Folder\Static
echo 17) In "%FOLDER%" for "%TENANT_USER_GROUP%" - deny "Delete" to "This folder only"
echo icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)
icacls "%FOLDER%" /C /deny "%TENANT_USER_GROUP%":(DE)                                                                                                              	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_ADMIN_SHARE%
echo 18) In "%FOLDER%" for "%TENANT_ADMIN_GROUP%" - deny "Delete" to "This folder, subfolders and files", disable inheritance 
echo icacls "%FOLDER%" /C /deny "%TENANT_ADMIN_GROUP%":(OI)(CI)(DE)
icacls "%FOLDER%" /C /deny "%TENANT_ADMIN_GROUP%":(OI)(CI)(DE)		                                                                                      			>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_ADMIN_PRODUCT%\Configurations\Public
echo 19) In "%FOLDER%" for "%TENANT_USER_GROUP%" - grant "Read" to "This folder, subfolders and files"
echo icacls "%FOLDER%" /C /grant "%TENANT_USER_GROUP%":(OI)(CI)(GR)
icacls "%FOLDER%" /C /grant "%TENANT_USER_GROUP%":(OI)(CI)(GR)                                                                                                     	>>%RUNLOG%

echo **********************************************************************************************************************************************************************************
SET FOLDER=%TENANT_ADMIN_SHARE%
echo 20) In "%FOLDER%" - hide this folder and subfolders, but not files
echo attrib +h /d "%FOLDER%"
attrib +h /d "%FOLDER%"                                                                                                                                         	>>%RUNLOG%
SET FOLDER=%TENANT_ADMIN_PRODUCT%
echo attrib +h /d "%FOLDER%"
attrib +h /d "%FOLDER%"                                                                                                                                         	>>%RUNLOG%
echo attrib +h /d "%FOLDER%"
attrib +h /d "%FOLDER%"                                                                                                                                         	>>%RUNLOG%
echo attrib +h /d "%FOLDER%\Configurations"
attrib +h /d "%FOLDER%\Configurations"                                                                                                                          	>>%RUNLOG%
echo attrib +h /d "%FOLDER%\Configurations\Public"
attrib +h /d "%FOLDER%\Configurations\Public"                                                                                                                   	>>%RUNLOG%
echo attrib +h /d "%FOLDER%\Reports"
attrib +h /d "%FOLDER%\Reports"                                                                                                                                 	>>%RUNLOG%

SET FOLDER=%TENANT_USER_PRODUCT%\Processing Results\Recap
echo 20) In "%FOLDER%" - hide this folder
echo attrib +h /d "%FOLDER%"
attrib +h /d "%FOLDER%"                                                                                                                                            	>>%RUNLOG%

SET FOLDER=%TENANT_USER_PRODUCT%\Reports\Frontier Custom Reports
echo 20) In "%FOLDER%" - hide this folder
echo attrib +h /d "%FOLDER%"
attrib +h /d "%FOLDER%"                                                                                                                                            	>>%RUNLOG%

rem echo **********************************************************************************************************************************************************************************
rem echo.
rem echo Copying template files to the tenant...

rem copy the template tenant files
rem echo.
rem xcopy /h /y "%TEMPLATE_ROOT_FOLDER%\ReplaceTenantParameters.ps1.tmp"      "%TENANT_ROOT_FOLDER%\ReplaceTenantParameters.ps1*"
rem xcopy /h /y "%TEMPLATE_ADMIN_PRODUCT%\Configurations\BouncyCastle.Crypto.dll.tmp" "%TENANT_ADMIN_PRODUCT%\Configurations\BouncyCastle.Crypto.dll"
rem xcopy /h /y "%TEMPLATE_ADMIN_PRODUCT%\Configurations\*.*"                 "%TENANT_ADMIN_PRODUCT%\Configurations"
rem xcopy /h /y "%TEMPLATE_ADMIN_PRODUCT%\Configurations\public\*.*"          "%TENANT_ADMIN_PRODUCT%\Configurations\public"
rem xcopy /h /y "%TEMPLATE_USER_PRODUCT%\Processing Results\Recap\schema.ini" "%TENANT_USER_PRODUCT%\Processing Results\Recap"

:DONE
echo.
echo ****************************************************************************** SUCCESS *******************************************************************************************

set RETURN=0
goto END

:ERROR
echo.
echo ****************************************************************************** FAILURE *******************************************************************************************
set RETURN=100

:USAGE
echo.
echo Usage: "%~nx0" ^<tenant^> ^<environment=dev/qa/test/prod^> ^<create groups=y/n^> ^<create folders=y/n^> ^<apply folder security=y/n^> ^<svc_acct_password=(optional)^> ^<file server=(optional)^>
echo Example 1: "%~nx0" test_tenant dev y y y        ^(create users and groups, create folders, apply folder security^)
echo Example 2: "%~nx0" test_tenant dev n n y abc123 ^(apply folder security, , use abc123 as a password for tenant service account^)
echo Example 3: "%~nx0" test_tenant dev y n y abc123 co.com ^(create users and groups, apply folder security, use abc123 as a password for tenant service account, use co.com as a file server^)
echo Example 4: "%~nx0" test_tenant dev n n n        ^(only list params and folders, but do not do anything else^)
set RETURN=999

:END
@Prompt $P$G
exit /b %RETURN%

REM FUNCTIONS BELOW
:Format Fmt [Str1] [Str2]...
setlocal disableDelayedExpansion
set fmt=%~1
set line=
set "space=                                                                                                    "
setlocal enableDelayedExpansion
for %%n in (^"^

^") do for /f "tokens=1,2 delims=[" %%a in (".!fmt:]=%%~n.!") do (
  if "!!" equ "" endlocal
  set "const=%%a"
  call set "subst=%%~2%space%%%~2"
  setlocal enableDelayedExpansion
  if %%b0 geq 0 (set "subst=!subst:~0,%%b!") else set "subst=!subst:~%%b!"
  for /f delims^=^ eol^= %%c in ("!line!!const:~1!!subst!") do (
    endlocal
    set "line=%%c"
  )
  shift /2
)
setlocal enableDelayedExpansion
echo(!line!
exit /b

@endlocal

:CheckUsage
SET PARAM_TO_CHECK=%~1
SET ALLOWED_VALUES=%~2
SET PARAMGOOD=0
SET RESULT=%PARAM_TO_CHECK%
FOR %%A IN (%ALLOWED_VALUES%) DO (
    if /i "%%A"=="[empty]" (
		if /i "%PARAM_TO_CHECK%"=="" (
			SET PARAMGOOD=1
		)
	) else (
		if /i "%%A"=="%PARAM_TO_CHECK%" (
			if /i "%PARAM_TO_CHECK%"=="0"  	    SET RESULT=0
			if /i "%PARAM_TO_CHECK%"=="n"  	    SET RESULT=0
			if /i "%PARAM_TO_CHECK%"=="no"      SET RESULT=0
			if /i "%PARAM_TO_CHECK%"=="false"   SET RESULT=0
			if /i "%PARAM_TO_CHECK%"=="y"  	    SET RESULT=1
			if /i "%PARAM_TO_CHECK%"=="yes"     SET RESULT=1
			if /i "%PARAM_TO_CHECK%"=="true"    SET RESULT=1
			SET PARAMGOOD=1
		)
    )
)
set "%~3=%RESULT%"
exit /b %PARAMGOOD%