if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
} 

$Script = "Remove-User"
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
function Remove-User {
    try {
        `$username = Select-User

        Write-Text -Type "header" -Text "Delete user data" -LineBefore
        
        `$options = @(
            "Delete  - Also delete the users data.",
            "Keep    - Do not delete the users data."
            "Back    - Go back to action selection."
        )

        `$choice = Get-Option -Options `$options
        if (`$choice -eq 0) { `$deleteData = `$true }
        if (`$choice -eq 1) { `$deleteData = `$false }
        if (`$choice -eq 2) { Select-Action -Username `$username }

        Write-Text -Type "header" -Text "Confirm user deletion" -LineBefore

        if (`$deleteData) {
            Write-Text -Type "notice" "NOTICE: You're about to delete this account and it's data!"
        } else {
            Write-Text -Type "notice"  "NOTICE: You're about to delete this account!"
        }

        `$data = Get-AccountInfo `$username

        Write-Box -Text `$data

        `$options = @(
            "Submit  - Confirm and apply." 
            "Reset   - Start over at the beginning."
            "Exit    - Run a different command."
        )
        
        `$choice = Get-Option -Options `$options

        if (`$choice -ne 0 -and `$choice -ne 2) { Invoke-Script "Remove-User" }
        if (`$choice -eq 2) { Write-Exit -Script "Remove-User" }

        Remove-LocalUser -Name `$username

        Write-Text -Type "done" -Text "Local user removed." -LineBefore
        
        if (`$deleteData) {
            `$userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '`$(`$user.SID)'"
            `$dir = `$userProfile.LocalPath
            if (`$null -ne `$dir -And (Test-Path -Path `$dir)) { 
                Remove-Item -Path `$dir -Recurse -Force 
                Write-Text -Type "done" -Text "User data deleted."
            } else {
                Write-Text "No data found."
            }
        }

        Write-Text -Type "success" -Text "The user has been deleted."

        `$resetOptions = @(
            "Remove another user  - Start over and remove another user." 
            "Exit                 - Quit this script with an opportunity to run another."
        )
        
        `$choice = Get-Option -Options `$resetOptions

        if (`$choice -ne 0 -and `$choice -ne 2) { Invoke-Script "Remove-User" }
        if (`$choice -eq 2) { Write-Exit -Script "Remove-User" }
    } catch {
        Write-Text -Type "error" -Text "Remove User Error: `$(`$_.Exception.Message)"
        Write-Exit
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

        `$data = @(
            "Name:`$Username"
            "Groups:`$(`$groups -join ';')"
            "Path:`$dir"
            "Source:`$source"
        )

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