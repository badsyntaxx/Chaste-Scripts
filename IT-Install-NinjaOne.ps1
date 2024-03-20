if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
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
    try {
        Write-Host "Chaste Scripts: Install NinjaOne" -ForegroundColor DarkGray
        Write-Text -Type "header" -Text "Install NinjaOne" -LineBefore -LineAfter

        Add-TempFolder
        Invoke-Installation

        Write-Exit
    } catch {
        Write-Text "Install error: `$(`$_.Exception.Message)" -Type "error"
    }
}

function Add-TempFolder {
    try {
        Write-Text "Creating TEMP folder..."
        Write-Text "Path: C:\Users\`$env:username\Desktop\"

        if (-not (Test-Path -PathType Container "C:\Users\`$env:username\Desktop\TEMP")) {
            New-Item -Path "C:\Users\`$env:username\Desktop\" -Name "TEMP" -ItemType Directory | Out-Null
        }
        
        Write-Text -Type "done" -Text "Folder created." -LineAfter
    } catch {
        Write-Text "Error creating temp folder: `$(`$_.Exception.Message)" -Type "error"
    }
}

function Invoke-Installation {
    `$url = "https://app.ninjarmm.com/agent/installer/3b7909f8-b6bf-4fc9-9fd4-fa5d332415f7/intechtogetherunassigned-5.7.8836-windows-installer.msi"
    `$paths = @("C:\Program Files\NinjaRemote")
    `$appName = "NinjaOne"
    `$installed = Find-ExistingInstall -Paths `$paths -App `$appName
    if (!`$installed) { Install-Program -Url `$url -AppName `$appName -Args "/qn" }
}

function Find-ExistingInstall {
    param (
        [parameter(Mandatory = `$true)]
        [array]`$Paths,
        [parameter(Mandatory = `$true)]
        [string]`$App
    )

    Write-Text "Checking for existing install..."

    `$installationFound = `$false
    `$service = Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue

    if (`$null -ne `$service -and `$service.Status -eq "Running") {
        `$installationFound = `$true
    }

    if (`$installationFound) { Write-Text -Type "success" -Text "`$App already installed." -LineAfter } 
    else { Write-Text "`$App not found."  -LineAfter}

    return `$installationFound
}

function Install-Program {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Url,
        [parameter(Mandatory = `$true)]
        [string]`$AppName,
        [parameter(Mandatory = `$false)]
        [string]`$Args = ""
    )

    try {
        `$tempPath = "C:\Users\`$env:username\Desktop\TEMP"
        `$download = Get-Download -Url `$Url -Target "`$tempPath\`$AppName.msi"

        if (`$download) {
            Write-Text -Text "Intalling..." -LineBefore

            # Start-Process -FilePath "msiexec" -ArgumentList "/i ``"`$tempPath\`$AppName.msi``" `$Args" -Wait

            `$service = Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue

            if (`$null -ne `$service -and `$service.Status -eq "Running") {
                Write-Text -Type "success" -Text "`$AppName successfully installed." -LineAfter
            } else {
                Write-Text -Type "error" -Text "`$AppName did not successfully install." -LineAfter
            }
        } else {
            Write-Text "Download failed. Skipping." -Type "error" -LineAfter
        }
    } catch {
        Write-Text -Type "error" -Text "Installation Error: `$(`$_.Exception.Message)"
        Write-Exit -Script "Install-NinjaOne"
    }
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $addLocalUser
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -File "$path\$Script.ps1" -Verb RunAs

