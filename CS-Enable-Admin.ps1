if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
} 

$Script = "Enable-BuiltInAdminAccount"
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
$path = if ($isAdmin) { "$env:SystemRoot\Temp" } else { "$env:TEMP" }

if (Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -ErrorAction SilentlyContinue) {
    $framework = Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -Raw
    Write-Host "   Using local file."
    Start-Sleep 1
} else {
    $framework = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1"
}

$core = @"
function Enable-BuiltInAdminAccount {
    Write-Host "Chaste Scripts: Enable Administrator Account" -ForegroundColor DarkGray
    Write-Text -Type "header" -Text "Toggle admin account" -LineBefore

    `$options = @(
        "Enable   - Enable the Windows built in administrator account.",
        "Disable  - Disable the built in administrator account."
    )
    
    `$choice = Get-Option -Options `$options

    if (`$choice -ne 0 -and `$choice -ne 1) { Enable-BuiltInAdminAccount }

    if (`$choice -eq 0) { 
        Write-Text -Text "Enabling the administrator account..." -LineBefore
        Get-LocalUser -Name "Administrator" | Enable-LocalUser 
        `$message = "Administrator account enabled."
    } 

    if (`$choice -eq 1) { 
        Write-Text -Text "Disabling the administrator account..." -LineBefore
        Get-LocalUser -Name "Administrator" | Disable-LocalUser 
        `$message = "Administrator account Disabled."
    }

    Write-Exit -Message `$message -Script "Enable-BuiltInAdminAccount"
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -File "$path\$Script.ps1" -Verb RunAs