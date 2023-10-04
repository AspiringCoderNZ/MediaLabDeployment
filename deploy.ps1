#Create new directory DeploymentShare
New-Item -Path "C:\DeploymentShare" -ItemType directory
New-SmbShare -Name "DeploymentShare" -Path "C:\DeploymentShare" -FullAccess Administrators
#Imort MDT Toolkit Module 
Import-Module "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"
#Create new PS drive and specify the path
new-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root "C:\DeploymentShare" -Description "MDT Deployment Share" -NetworkPath "\\SRV-Media\DeploymentShare" -Verbose | add-MDTPersistentDrive -Verbose
#Import Applcations Adobe Reader into MDT share
Import-MDTApplication -path "DS001:\Applications" -enable "True" -Name "Adobe reader 9" -ShortName "reader" -Version "9" -Publisher "Adobe" -Language "English" -CommandLine "Reader.exe /sAll /rs /l" -WorkingDirectory ".\Applications\Adobe reader 9" -ApplicationSourcePath "C:\adobe" -DestinationFolder "Adobe reader 9" -Verbose
#Import Applcations VLC  into MDT share
import-MDTApplication -path "DS001:\Applications" -enable "True" -Name "VideoLan vlc 1" -ShortName "vlc" -Version "1" -Publisher "VideoLan" -Language "English" -CommandLine "vlc.exe /s /v /qn" -WorkingDirectory ".\Applications\VideoLan vlc 1" -ApplicationSourcePath "C:\vlc" -DestinationFolder "VideoLan vlc 1" -Verbose
#Import Applcations Google into MDT share
import-MDTApplication -path "DS001:\Applications" -enable "True" -Name "Google Chrome 1" -ShortName "Chrome" -Version "1" -Publisher "Google" -Language "English" -CommandLine "MsiExec.exe /i googlechrome.msi /qn" -WorkingDirectory ".\Applications\Google Chrome 1" -ApplicationSourcePath "C:\google" -DestinationFolder "Google Chrome 1" -Verbose
#Import Operating System into MDT share
import-mdtoperatingsystem -path "DS001:\Operating Systems" -SourcePath "C:\Windows 11" -DestinationFolder "Windows 11" -Verbose
#Define tasksquence, update CustomSetting and Bootstrap 
import-mdttasksequence -path "DS001:\Task Sequences" -Name "OS with app" -Template "Client.xml" -Comments "Deploying Windows 11" -ID "1" -Version "1.0" -OperatingSystemPath "DS001:\Operating Systems\Windows 11 Pro in Windows 11 install.wim" -FullName "Windows User" -OrgName "Media" -HomePage "about:blank" -Verbose

$CSFile = @"
[Settings]
Priority=Default
Properties=MyCustomProperty

[Default]
OSInstall=Y
SkipCapture=YES
SkipComputerBackup=YES
SkipAdminPassword=YES
SkipProductKey=YES
SkipDeploymentType=YES
SkipDomainMembership=YES
SkipUserData=YES
SkipBDDWelcome=YES
SkipComputerName=YES
SkipTaskSequence=YES
TaskSequenceID=1
SkipLocaleSelection=YES
UserLocale=en-US
KeyboardLocale=en-US
SkipTimeZone=YES
TimeZoneName=GMT Standard Time
SkipApplications=NO
SkipBitLocker=YES
SkipSummary=YES
EventServices=http://Deployment:9800
"@ 

Remove-Item -Path "C:\DeploymentShare\Control\CustomSettings.ini" -Force
New-Item -Path "C:\DeploymentShare\Control\CustomSettings.ini" -ItemType File
Set-Content -Path "C:\DeploymentShare\Control\CustomSettings.ini" -Value $CSFile

$BSFile = @"
[Settings]
Priority=Default

[Default]
DeployRoot=\\Server-Mlab\DeploymentShare
UserID=Administrator
UserPassword=Admin@2023
UserDomain=Media.com
SkipBDDWelcome=YES
TaskSequenceID=1
"@ 

Remove-Item -Path "C:\DeploymentShare\Control\BootStrap.ini" -Force
New-Item -Path "C:\DeploymentShare\Control\BootStrap.ini" -ItemType File
Set-Content -Path "C:\DeploymentShare\Control\BootStrap.ini" -Value $BSFile

$XMLFile = "C:\DeploymentShare\Control\Settings.xml"
            [xml]$SettingsXML = Get-Content $XMLFile
            $SettingsXML.Settings."SupportX86" = "False"
            $SettingsXML.Save($XMLFile)


#Update MDT deploymentShare
update-MDTDeploymentShare -path "DS001:" -Force -Verbose

#Intall WDS Server and initialize 
Install-WindowsFeature -Name WDS -IncludeManagementTools

$WDSPath = 'C:\RemoteInstall'
wdsutil /Verbose /Progress /Initialize-Server /Reminst:$WDSPath
Start-Sleep -s 20

wdsutil /Verbose /Start-Server
Start-Sleep -s 20

#Ensure responding to clients
WDSUTIL /Set-Server /AnswerClients:All
Import-WdsBootImage -Path "C:\DeploymentShare\Boot\LiteTouchPE_x64.wim" -NewImageName "LiteTouchPE_x64" -SkipVerify

