if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

$script = "Edit-User"
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
 This function creates a new local user account on a Windows system with specified settings, 
 including the username, optional password, and group. The account and password never expire.
"@

$core = @"
function $script {
    try {
        Get-Item -ErrorAction SilentlyContinue "$path\$script.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host "`n Chaste Scripts: Edit User v0315241122"
        Write-Host "$des" -ForegroundColor DarkGray

        Write-Text -Type "header" -Text "What type of edit would you like to make?" -LineBefore -LineAfter

        `$choice = Get-Option -Options @(
            'Edit user name      - Edit a local users name.'
            'Edit user password  - Edit a local users password.'
            'Edit user group     - Edit a local users group.'
        )

        if (`$choice -eq 0) { irm chaste.dev/edit/user/name | iex }
        if (`$choice -eq 1) { irm chaste.dev/edit/user/password | iex }
        if (`$choice -eq 2) { irm chaste.dev/edit/user/group | iex }
    } catch {
        Write-Text -Type "error" -Text "Add user error: `$(`$_.Exception.Message)"
        Write-Exit
    }
}

"@

New-Item -Path "$path\$script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$script.ps1" -Value $core
Add-Content -Path "$path\$script.ps1" -Value $framework
Add-Content -Path "$path\$script.ps1" -Value "Invoke-Script '$script'"

PowerShell.exe -NoExit -File "$path\$script.ps1" -Verb RunAs