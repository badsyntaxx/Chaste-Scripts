if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
    Exit;
} 

$Script = "Enable-BuiltInAdminAccount"
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
$path = if ($isAdmin) { "$env:SystemRoot\Temp" } else { "$env:TEMP" }
$framework = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1"

if (Get-Content -Path "C:\Users\$env:username\Documents\Dev\Chaste-Scripts\CS-Framework.ps1" -ErrorAction SilentlyContinue) {
    Write-Host "Using local file"
    Start-Sleep 1
    $framework = Get-Content -Path "C:\Users\$env:username\Documents\Dev\Chaste-Scripts\CS-Framework.ps1" -Raw
}

$editLocalUser = @"
function Enable-BuiltInAdminAccount {
    Clear-Host
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
        Write-Text -Type "done" -Text "Administrator account enabled."
    } 

    if (`$choice -eq 1) { 
        Write-Text -Text "Disabling the administrator account..." -LineBefore
        Get-LocalUser -Name "Administrator" | Disable-LocalUser 
        Write-Text -Type "done" -Text "Administrator account Disabled."
    }

    Write-CloseOut "The administrator account was toggled." -Script "Enable-BuiltInAdminAccount"
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $editLocalUser
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Initialize-Script '$Script'"

PowerShell.exe -File "$path\$Script.ps1" -Verb RunAs