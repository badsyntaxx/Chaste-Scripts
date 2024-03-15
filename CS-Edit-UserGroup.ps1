if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
} 

$Script = "Edit-UserGroup"
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
   This script allows you to modify the group membership of a user on a Windows system. 
   It provides menus for selecting the user and the desired group (Administrators or Users).
"@

$core = @"
function Edit-UserGroup {
    try {
        Write-Host "`n   Chaste Scripts: Edit User Group v0315240354"
        Write-Host "$des" -ForegroundColor DarkGray

        `$username = Select-User

        Write-Text -Type "header" -Text "Select user group" -LineBefore

        `$options = @(
            "Administrator  - Make this user an administrator."
            "Standard User  - Make this user a standard user."
        )

        `$group = Get-Option -Options `$options

        switch (`$group) {
            0 { `$group = 'Administrators' }
            1 { `$group = 'Users' }
        }

        `$data = Get-AccountInfo -Username `$username

        Write-Text -Type "notice" -Text "## You're about to change this users group membership." -LineBefore -LineAfter
        Write-Box -Text `$data

        `$options = @(
            "Submit  - Confirm and apply." 
            "Reset   - Start over at the beginning."
            "Exit    - Run a different command."
        )
        
        `$choice = Get-Option -Options `$options -LineBefore
        if (`$choice -ne 0 -and `$choice -ne 1 -and `$choice -ne 2) { Edit-UserGroup }
        if (`$choice -eq 1) { Invoke-Script "Edit-LocalUser" }
        if (`$choice -eq 2) { Write-Exit -Script "Edit-LocalUser" }

        Write-Text -Type "notice" -Text "Applying group membership..." -LineBefore

        Remove-LocalGroupMember -Group "Administrators" -Member `$username -ErrorAction SilentlyContinue

        Add-LocalGroupMember -Group `$group -Member `$username -ErrorAction SilentlyContinue | Out-Null

        Write-Text -Type "notice" -Text "Group membership applied."

        Write-Host
        Write-Exit "The group membership for `$username has been changed to `$group." -Script "Edit-LocalUser"
    } catch {
        Write-Text -Type "error" -Text "Edit group error: `$(`$_.Exception.Message)"
        Write-Exit -Script "Edit-UserGroup"
    }
} 

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -File "$path\$Script.ps1" -Verb RunAs