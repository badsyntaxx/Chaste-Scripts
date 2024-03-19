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

$des = @"
   This script allows you to toggle the built in admin account on a Windows system. 
   It provides an interactive menu for you to enable or disable the account.
"@

$core = @"
function Enable-BuiltInAdminAccount {
    try { 
        Get-Item -ErrorAction SilentlyContinue "$path\$script.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host "`n   Chaste Scripts: Edit User Name v0315240404"
        Write-Host "$des" -ForegroundColor DarkGray

        Write-Text -Type "header" -Text "Toggle admin account" -LineBefore -LineAfter

        `$admin = Get-LocalUser -Name "Administrator"

        Write-Host "    Administrator:" -NoNewLine

        if (`$admin.Enabled) { Write-Host "Enabled" -ForegroundColor Yellow} 
        else { Write-Host "Disabled" -ForegroundColor Yellow }

        Write-Host

        `$options = @(
            "Enable   - Enable the Windows built in administrator account.",
            "Disable  - Disable the built in administrator account."
        )
        
        `$choice = Get-Option -Options `$options -LineAfter

        if (`$choice -ne 0 -and `$choice -ne 1) { Enable-BuiltInAdminAccount }

        if (`$choice -eq 0) { 
            Get-LocalUser -Name "Administrator" | Enable-LocalUser 
            `$message = "Administrator account enabled."
        } 

        if (`$choice -eq 1) { 
            Get-LocalUser -Name "Administrator" | Disable-LocalUser 
            `$message = "Administrator account Disabled."
        }

        Write-Exit -Message `$message -Script "Enable-Admin"
    } catch {
        Write-Text -Type "error" -Text "Enable admin error: `$(`$_.Exception.Message)"
        Write-Exit -Script "Enable-Admin"
    }
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -File "$path\$Script.ps1" -Verb RunAs