if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
} 

$Script = "Install-ISRApps"
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
$path = if ($isAdmin) { "$env:SystemRoot\Temp" } else { "$env:TEMP" }

if (Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -ErrorAction SilentlyContinue) {
    $framework = Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -Raw
    Write-Host "   Using local file."
    Start-Sleep 1
} else {
    $framework = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1"
}

$addLocalUser = @"
function Install-ISRApps {
    Write-Host "Chaste Scripts" -ForegroundColor DarkGray
    Write-Text "Select user" -Type "header" -LineBefore
    Select-LocalUser
    Add-TempFolder
    Install-NinjaOne
    Install-GoogleChrome
    Install-GoogleChromeBookmarks
    Install-Slack
    Install-Zoom
    Install-RingCentral
    Install-RevoUninstaller
    Install-AdobeAcrobatReader
    Install-Balto
    Install-ExplorerPatcher
    Initialize-Cleanup
    Add-EPRegedits
    Read-Host "   Press Any Key to continue"
}

function Add-TempFolder {
    try {
        Write-Text "Creating TEMP folder" -Type "header" -LineBefore
        Write-Text "Path: C:\Users\`$account\Desktop\"
        `$folderPath = "C:\Users\`$account\Desktop\TEMP"
        if (-not (Test-Path -PathType Container `$folderPath)) {
            New-Item -Path `$folderPath -Name "TEMP" -ItemType Directory | Out-Null
        }
        Write-Text "Folder created" -Type "done"
    } catch {
        Write-Text "ERROR: `$(`$_.Exception.Message)" -Type "error"
        Write-Text "Skipping `$AppName installation."
    }
}

function Install-NinjaOne {
    `$paths = @("C:\Program Files\NinjaRemote")
    `$url = "https://app.ninjarmm.com/agent/installer/0274c0c3-3ec8-44fc-93cb-79e96f191e07/nuviaisrcenteroremut-5.7.8652-windows-installer.msi"
    `$appName = "NinjaOne"
    `$installed = Find-ExistingInstall -Paths `$paths -App `$appName
    if (!`$installed) { Install-Program `$url `$appName "msi" "/qn" }
}

function Install-GoogleChrome {
    `$paths = @(
        "`$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "`$env:ProgramFiles (x86)\Google\Chrome\Application\chrome.exe",
        "C:\Users\`$account\AppData\Google\Chrome\Application\chrome.exe"
    )

    `$url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
    `$appName = "Google Chrome"
    `$installed = Find-ExistingInstall -Paths `$paths -App `$appName
    if (!`$installed) { Install-Program `$url `$appName "msi" "/qn" }
}

function Install-GoogleChromeBookmarks {
    try {
        Write-Text "Adding Nuvia bookmarks..." -LineBefore
        `$tempPath = "C:\Users\`$account\Desktop\TEMP"
        `$download = Get-Download -Uri "https://drive.google.com/uc?export=download&id=1WmvSnxtDSLOt0rgys947sOWW-v9rzj9U" -Target "`$tempPath\Bookmarks"
        if (`$download) {
            ROBOCOPY "`$tempPath" "C:\Users\`$account\AppData\Local\Google\Chrome\User Data\Default" "Bookmarks" /NFL /NDL /NJH /NJS /nc /ns | Out-Null
            Write-Text -Type "done" -Text "Bookmarks added to chrome."
        }
    } catch {
        Write-Text "Bookmarks Error: `$(`$_.Exception.Message)" -Type "error"
        Read-Text "Press any key to continue"
    }
}

function Install-Slack {
    `$paths = @(
        "C:\Program Files\Slack\slack.exe",
        "C:\Users\`$account\AppData\slack\slack.exe"
    )
    `$url = "https://downloads.slack-edge.com/releases/windows/4.36.138/prod/x64/slack-standalone-4.36.138.0.msi"
    `$appName = "Slack"
    `$installed = Find-ExistingInstall -Paths `$paths -App `$appName
    if (!`$installed) { Install-Program `$url `$appName "msi" "/qn" }
}

function Install-Zoom {
    `$paths = @(
        "C:\Program Files\Zoom\Zoom.exe",
        "C:\Program Files\Zoom\bin\Zoom.exe",
        "C:\Users\`$account\AppData\Zoom\Zoom.exe"
    )
    `$url = "https://zoom.us/client/latest/ZoomInstallerFull.msi?archType=x64"
    `$appName = "Zoom"
    `$installed = Find-ExistingInstall -Paths `$paths -App `$appName
    if (!`$installed) { Install-Program `$url `$appName "msi" "/qn" }
}

function Install-RingCentral {
    `$paths = @("C:\Program Files\RingCentral\RingCentral.exe")
    `$url = "https://app.ringcentral.com/download/RingCentral-x64.msi"
    `$appName = "Ring Central"
    `$installed = Find-ExistingInstall -Paths `$paths -App `$appName
    if (!`$installed) { Install-Program `$url `$appName "msi" "/qn" }
}

function Install-RevoUninstaller {
    `$paths = @("C:\Program Files\VS Revo Group\Revo Uninstaller\RevoUnin.exe")
    `$url = "https://download.revouninstaller.com/download/revosetup.exe"
    `$appName = "Revo Uninstaller"
    `$installed = Find-ExistingInstall -Paths `$paths -App `$appName
    if (!`$installed) { Install-Program `$url `$appName "exe" "/verysilent" }
}

function Install-AdobeAcrobatReader {
    `$paths = @("C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe")
    `$url = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2300820555/AcroRdrDC2300820555_en_US.exe"
    `$appName = "Adobe Acrobat Reader"
    `$installed = Find-ExistingInstall -Paths `$paths -App `$appName
    if (!`$installed) { Install-Program `$url `$appName "exe" "/sAll /rs /msi EULA_ACCEPT=YES" }
}

function Install-Balto {
    `$paths = @("C:\Users\`$account\AppData\Local\Programs\Balto\Balto.exe")
    `$url = "https://download.baltocloud.com/Balto+Setup+6.0.1.exe"
    `$appName = "Balto"
    `$installed = Find-ExistingInstall -Paths `$paths -App `$appName
    if (!`$installed) { Install-Program `$url `$appName "exe" "/quiet" }
}

function Install-ExplorerPatcher {
    `$paths = @("C:\Program Files\ExplorerPatcher\ep_gui.dll")
    `$url = "https://github.com/valinet/ExplorerPatcher/releases/download/22621.2861.62.2_9b68cc0/ep_setup.exe"
    `$appName = "ExplorerPatcher"
    `$installed = Find-ExistingInstall -Paths `$paths -App `$appName
    if (!`$installed) { Install-Program `$url `$appName "exe" "/quiet" }
}

function Initialize-Cleanup {
    Remove-Item "C:\Users\`$script:account\Desktop\Revo Uninstaller.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Users\Public\Desktop\Revo Uninstaller.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Users\`$script:account\Desktop\Adobe Acrobat.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Users\Public\Desktop\Adobe Acrobat.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Users\`$script:account\Desktop\Microsoft Edge.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Users\Public\Desktop\Microsoft Edge.lnk" -Force -ErrorAction SilentlyContinue
}

function Add-EPRegedits {
    Write-Text "Configuring explorer."
    `$regCommands = @(
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "ImportOK" /t REG_DWORD /d 1 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "OldTaskbar" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" /v "SearchboxTaskbarMode" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowTaskViewButton" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarDa" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "SkinMenus" /t REG_DWORD /d 1 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "CenterMenus" /t REG_DWORD /d 1 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "FlyoutMenus" /t REG_DWORD /d 1 /f',
        'reg add "HKEY_CURRENT_USER\Software\Microsoft\TabletTip\1.7" /v "TipbandDesiredVisibility" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "HideControlCenterButton" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarSD" /t REG_DWORD /d 1 /f',
        'reg add "HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /v "" /t REG_SZ /d "" /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "LegacyFileTransferDialog" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "UseClassicDriveGrouping" /t REG_DWORD /d 1 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "DisableImmersiveContextMenu" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "ShrinkExplorerAddressBar" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "HideExplorerSearchBar" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "MicaEffectOnTitlebar" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_ShowClassicMode" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAl" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartPage" /v "MonitorOverride" /t REG_DWORD /d 1 /f',
        'reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartPage" /v "MakeAllAppsDefault" /t REG_DWORD /d 1 /f',
        'reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "AltTabSettings" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "LastSectionInProperties" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "ClockFlyoutOnWinC" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "ToolbarSeparators" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "PropertiesInWinX" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "NoMenuAccelerator" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "DisableOfficeHotkeys" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "DisableWinFHotkey" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "DisableAeroSnapQuadrants" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_PowerButtonAction" /t REG_DWORD /d 2 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "DoNotRedirectSystemToSettingsApp" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "DoNotRedirectProgramsAndFeaturesToSettingsApp" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "DoNotRedirectDateAndTimeToSettingsApp" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "DoNotRedirectNotificationIconsToSettingsApp" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "UpdatePolicy" /t REG_DWORD /d 1 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "UpdatePreferStaging" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "UpdateAllowDowngrades" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "UpdateURL" /t REG_SZ /d "" /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "UpdateURLStaging" /t REG_SZ /d "" /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "AllocConsole" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "Memcheck" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "TaskbarAutohideOnDoubleClick" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "PaintDesktopVersion" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "ClassicThemeMitigations" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "NoPropertiesInContextMenu" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "EnableSymbolDownload" /t REG_DWORD /d 1 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "ExplorerReadyDelay" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\ExplorerPatcher" /v "XamlSounds" /t REG_DWORD /d 0 /f',
        'reg add "HKEY_CURRENT_USER\Software\ExplorerPatcher" /v "Language" /t REG_DWORD /d 0 /f'
    )

    foreach (`$cmd in `$regCommands) {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `$cmd"
    }

    Write-Text "Explorer configured" -Type "done" -LineAfter
}

function Select-LocalUser {
    `$accountNames = @()
    `$localUsers = Get-LocalUser
    `$excludedAccounts = @("DefaultAccount", "Administrator", "WDAGUtilityAccount", "Guest", "defaultuser0")

    foreach (`$user in `$localUsers) {
        if (`$user.Name -notin `$excludedAccounts) { `$accountNames += `$user.Name }
    }

    
    `$choice = Get-Option -Options `$accountNames

    `$script:account = `$accountNames[`$choice]
}

function Find-ExistingInstall {
    param (
        [parameter(Mandatory = `$true)]
        [array]`$Paths,
        [parameter(Mandatory = `$true)]
        [string]`$App
    )

    Write-Text -Type "header" -Text "Installing `$App" -LineBefore
    Write-Text "Checking for existing install..."
    `$installationFound = `$false
    foreach (`$path in `$paths) {
        if (Test-Path `$path) {
            `$installationFound = `$true
            break
        }
    }
    if (`$installationFound) {
        Write-Text -Type "success" -Text "`$App already installed."
    } else {
        Write-Text "`$App not found."
    }

    return `$installationFound
}

function Install-Program {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Url,
        [parameter(Mandatory = `$true)]
        [string]`$AppName,
        [parameter(Mandatory = `$true)]
        [string]`$Extenstion,
        [parameter(Mandatory = `$true)]
        [string]`$Args
    )

    try {
        if (`$Extenstion -eq "msi") { `$output = "`$AppName.msi" } else { `$output = "`$AppName.exe" }
        
        `$tempPath = "C:\Users\`$account\Desktop\TEMP"
        `$download = Get-Download -Uri `$Url -Target "`$tempPath\`$output"

        if (`$download) {
            Write-Text -Text "Intalling..."
            if (`$Extenstion -eq "msi") {
                Start-Process -FilePath "msiexec" -ArgumentList "/i ``"`$tempPath\`$output``" `$Args" -Wait
            } else {
                Start-Process -FilePath "`$tempPath\`$output" -ArgumentList "`$Args" -Wait
            }
           
            Write-Text -Type "success" -Text "`$AppName successfully installed."
        } else {
            Write-Text "Download failed. Skipping." -Type "error" -LineAfter
        }
    } catch {
        Write-Text "Installation Error: `$(`$_.Exception.Message)" -Type "error"
        Write-Text "Skipping `$AppName installation."
    }
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $addLocalUser
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -File "$path\$Script.ps1" -Verb RunAs

