if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
} 

$Script = "Edit-UserPassword"
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
   This script allows you to modify the password of a user on a Windows system. 
   You can leave the password blank to remove an existing password.
"@

$core = @"
function Edit-UserPassword {
    try {
        Get-Item -ErrorAction SilentlyContinue "$path\$script.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host "`n   Chaste Scripts: Edit User Password v0315241122"
        Write-Host "$des" -ForegroundColor DarkGray

        `$username = Select-User

        Write-Text -Type "header" -Text "Enter password or leave blank" -LineBefore -LineAfter
        
        `$password = Get-Input -Prompt "" -IsSecure `$true

        if (`$password.Length -eq 0) { `$alert = "## You're about to remove this users password." } 
        else { `$alert = "## You're about to change this users password." }

        Write-Text -Type "notice" -Text `$alert -LineBefore -LineAfter

        `$options = @(
            "Submit  - Confirm and apply." 
            "Reset   - Start over at the beginning."
            "Exit    - Run a different command."
        )

        `$choice = Get-Option -Options `$options -LineAfter
        if (`$choice -ne 0 -and `$choice -ne 1 -and `$choice -ne 2) { Edit-UserPassword }
        if (`$choice -eq 1) { Invoke-Script "Edit-UserPassword" }
        if (`$choice -eq 2) { Write-Exit -Script "Edit-UserPassword" }

        Get-LocalUser -Name `$Username | Set-LocalUser -Password `$password

        Write-Exit -Message "The password for this account has been changed." -Script "Edit-UserPassword"
    } catch {
        Write-Text -Type "error" -Text "Edit password error: `$(`$_.Exception.Message)"
        Write-Exit -Script "Edit-UserPassword"
    }
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -File "$path\$Script.ps1" -Verb RunAs