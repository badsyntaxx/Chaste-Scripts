if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
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

$core = @"
function Edit-UserPassword {
    try {
        `$username = Select-User

        Write-Text -Type "header" -Text "Change or remove password" -LineBefore
        
        `$password = Get-Input -Prompt "Password" -IsSecure `$true

        if (`$password.Length -eq 0) { `$alert = "NOTICE: You're about to remove this users password." } 
        else { `$alert = "NOTICE: You're about to change this users password." }

        Write-Text -Type "header" -Text "Confirm password change" -LineBefore

        `$data = Get-AccountInfo `$Username

        Write-Text -Type "notice" -Text `$alert
        Write-Text -Type "recap" -Data `$data -LineAfter

        `$confirmation = @(
            "Submit  - Confirm and apply changes", 
            "Restart   - Start edit user over.", 
            "Exit    - Quit this script with an opportunity to run another."
        )

        `$choice = Get-Option -Options `$confirmation
        if (`$choice -ne 0 -and `$choice -ne 1 -and `$choice -ne 2) { Edit-UserPassword }
        if (`$choice -eq 1) { Invoke-Script "Edit-UserPassword" }
        if (`$choice -eq 2) { Write-Exit -Script "Edit-UserPassword" }

        `$account = Get-LocalUser -Name `$Username
        `$account | Set-LocalUser -Password `$password

        Write-Host
        Write-Exit -Message "The password for this account has been changed." -Script "Edit-UserPassword"
    } catch {
        Write-Text -Type "error" -Text "Set Password Error: `$(`$_.Exception.Message)"
    }
}

function Get-AccountInfo {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Username
    )

    try {
        `$user = Get-LocalUser -Name `$Username
        `$groups = Get-LocalGroup | Where-Object { `$user.SID -in (`$_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name"
        `$userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '`$(`$user.SID)'"
        `$dir = `$userProfile.LocalPath
        if (`$null -ne `$userProfile) { `$dir = `$userProfile.LocalPath } else { `$dir = "Awaiting first sign in." }

        `$source = Get-LocalUser -Name `$Username | Select-Object -ExpandProperty PrincipalSource

        `$data = [ordered]@{
            "Name"   = `$Username
            "Groups" = "`$(`$groups -join ';')"
            "Path"   = `$dir
            "Source" = `$source
        }

        return `$data
    } catch {
        Write-Alert -Type "error" -Text "ERROR: `$(`$_.Exception.Message)"
        Read-Host -Prompt "Press any key to continue"
    }
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -File "$path\$Script.ps1" -Verb RunAs