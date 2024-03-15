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
        Write-Host "Chaste Scripts: Install NinjaOne Silently" -ForegroundColor DarkGray
        Write-Text -Type "header" -Text "Install NinjaOne" -LineBefore

        `$url = Get-Input -Prompt "Paste install link"

        Add-TempFolder
        Invoke-Installation -Url `$url

        Read-Host "   Press Any Key to continue"
    } catch {
        Write-Text "Install error: `$(`$_.Exception.Message)" -Type "error"
    }
}

function Add-TempFolder {
    try {
        Write-Text "Creating TEMP folder"
        Write-Text "Path: C:\Users\`$env:username\Desktop\"

        `$folderPath = "C:\Users\`$env:username\Desktop\TEMP"

        if (-not (Test-Path -PathType Container `$folderPath)) {
            New-Item -Path `$folderPath -Name "TEMP" -ItemType Directory | Out-Null
        }
        
        Write-Text -Type "done" -Text "Folder created." -LineAfter
    } catch {
        Write-Text "ERROR: `$(`$_.Exception.Message)" -Type "error"
    }
}

function Invoke-Installation {
    param (
        [parameter(Mandatory = `$false)]
        [string]`$Url
    )

    `$paths = @("C:\Program Files\NinjaRemote")
    `$appName = "NinjaOne"
    `$installed = Find-ExistingInstall -Paths `$paths -App `$appName
    if (!`$installed) { Install-Program `$Url `$appName "/qn" }
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
    foreach (`$path in `$paths) {
        if (Test-Path `$path) {
            `$installationFound = `$true
            break
        }
    }

    if (`$installationFound) { Write-Text -Type "success" -Text "`$App already installed." -LineAfter } 
    else { Write-Text "`$App not found."  -LineAfter}

    return `$installationFound
}

function Install-Program {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Uri,
        [parameter(Mandatory = `$true)]
        [string]`$AppName,
        [parameter(Mandatory = `$true)]
        [string]`$Args
    )

    try {
        `$tempPath = "C:\Users\`$env:username\Desktop\TEMP"
        `$download = Get-Download -Url `$Uri -Target "`$tempPath\`$AppName.msi"

        Write-Text ""

        if (`$download) {
            Write-Text -Text "Intalling..."

            Start-Process -FilePath "msiexec" -ArgumentList "/i ``"`$tempPath\`$output``" `$Args" -Wait

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

