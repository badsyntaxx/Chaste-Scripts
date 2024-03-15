if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

$Script = "Add-LocalUser"
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
function Add-LocalUser {
    try {
        Write-Host "`n   Chaste Scripts: Add User"
        Write-Host "   Enter a name, a password (you can leave blank for no password) and select a group." -ForegroundColor DarkGray
        Write-Host "   Then confirm ." -ForegroundColor DarkGray
        Write-Text -Type "header" -Text "Enter name" -LineBefore

        `$name = Get-Input -Prompt "" -Validate "^([a-zA-Z0-9 _\-]{1,64})$"  -CheckExistingUser

        Write-Text -Type "header" -Text "Enter password" -LineBefore

        `$password = Get-Input -Prompt "" -IsSecure
        
        Write-Text -Type "header" -Text "Set group membership" -LineBefore
        
        `$choice = Get-Option -Options @("Administrator", "Standard user")
        if (`$choice -eq 0) { `$group = 'Administrators' } else { `$group = "Users" }
        if (`$group -eq 'Administrators') { `$groupDisplay = 'Administrator' } else { `$groupDisplay = 'Standard user' }

        `$options = @(
            "Submit  - Confirm and apply." 
            "Reset   - Start over at the beginning."
            "Exit    - Run a different command."
        )

        `$data = @(
            "Name:`$name"
            "Password:`$password"
            "Group:`$groupDisplay"
        )

        Write-Host
        Write-Text -Type "header" -Text "You're about to create a new local user!" -LineBefore
        Write-Box -Text `$data

        `$choice = Get-Option -Options `$options -LineBefore
        if (`$choice -ne 0 -and `$choice -ne 2) { Invoke-Script "Add-LocalUser" }
        if (`$choice -eq 2) {  Write-Exit -Script "Add-LocalUser" }

        Write-Text -Type "notice" -Text "Creating local user..." -LineBefore

        New-LocalUser `$name -Password `$password -Description "Local User" -AccountNeverExpires -PasswordNeverExpires -ErrorAction Stop | Out-Null

        Write-Text -Type "notice" -Text "Local user created."

        Add-LocalGroupMember -Group `$group -Member `$name -ErrorAction Stop

        Write-Text -Type "notice" -Text "Group membership set to `$group." -LineAfter

        Write-Exit -Message "The user account was created." -Script "Add-LocalUser" 
    } catch {
        Write-Text -Type "error" -Text "Add User Error: `$(`$_.Exception.Message)"
        Write-Exit
    }
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -NoExit -File "$path\$Script.ps1" -Verb RunAs