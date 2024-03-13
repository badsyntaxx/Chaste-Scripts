if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
    Exit;
} 

$Script = "Install-NinjaOne"
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
function Install-NinjaOne {
    Write-Host "Chaste Scripts" -ForegroundColor DarkGray
    Write-Text -Type "header" -Text "Install NinjaOne" -LineBefore
    Add-TempFolder
    Install-NinjaOne -Uri "https://app.ninjarmm.com/agent/installer/0274c0c3-3ec8-44fc-93cb-79e96f191e07/nuviaisrcenteroremut-5.7.8652-windows-installer.msi"
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
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Uri
    )

    `$paths = @("C:\Program Files\NinjaRemote")
    `$appName = "NinjaOne"
    `$installed = Find-ExistingInstall -Paths `$paths -App `$appName
    if (!`$installed) { Install-Program `$Uri `$appName "msi" "/qn" }
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
        [string]`$Uri,
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
        `$download = Get-Download -Uri `$Uri -Target "`$tempPath\`$output"

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

