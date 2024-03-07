if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
    Exit;
} 

$Script = "Add-LocalUser"
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
$path = if ($isAdmin) { "$env:SystemRoot\Temp" } else { "$env:TEMP" }
$framework = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1"

if (Get-Content -Path "C:\Users\$env:username\Documents\Dev\Chaste-Scripts\CS-Framework.ps1" -ErrorAction SilentlyContinue) {
    Write-Host "Using local file"
    Start-Sleep 1
    $framework = Get-Content -Path "C:\Users\$env:username\Documents\Dev\Chaste-Scripts\CS-Framework.ps1" -Raw
}

$addLocalUser = @"
function Add-LocalUser {
    try {
        Clear-Host
        Write-Host "Chaste Scripts: Create Local User`n`n" -ForegroundColor DarkGray
        Write-Text -Text "Credentials" -Type "header"

        `$name = Get-Input -Prompt "Username" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,15})$" 
        `$account = Get-LocalUser -Name `$name -ErrorAction SilentlyContinue

        while (`$null -ne `$account) {
            `$name = Get-Input -Prompt "Username" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,15})$" -Alert "ERROR: An account with that name already exists." -AlertType "error"
            `$account = Get-LocalUser -Name `$name -ErrorAction SilentlyContinue
        }
        
        `$password = Get-Input -Prompt "Password" -IsSecure `$true 
        
        Write-Text -Type "header" -Text "Group membership"
        
        `$choice = Get-Option -Options @("Administrator", "Standard user")
        if (`$choice -eq 0) { `$group = 'Administrators' } else { `$group = "Users" }
        if (`$group -eq 'Administrators') { `$groupDisplay = 'Administrator' } else { `$groupDisplay = 'Standard user' }

        `$options = @(
            "Submit   - Confirm and apply changes", 
            "Reset    - Start add user over.", 
            "Exit     - Start over back at task selection."
        )

        `$data = [ordered]@{}
        `$data["Name"] = `$name
        `$data["Password"] = `$password
        `$data["Group"] = `$groupDisplay 

        Write-Text "Confirm user settings" -Type "header" -LineBefore
        Write-Text -Type "notice" -Text "NOTICE: You're about to create a new local user!"
        Write-Text -Type "recap" -Data `$data -LineAfter

        `$choice = Get-Option -Options `$options

        if (`$choice -ne 0 -and `$choice -ne 2) { Add-LocalUser }
        if (`$choice -eq 2) { Invoke-RestMethod https://chaste.dev/s | Invoke-Expression }

        Write-Text -Type "header" -Text "Create local user" -LineBefore

        New-LocalUser `$name -Password `$password -Description "Local User" -AccountNeverExpires -PasswordNeverExpires -ErrorAction Stop | Out-Null

        Write-Text -Type "done" -Text "Local user created."

        Add-LocalGroupMember -Group `$group -Member `$name -ErrorAction Stop

        Write-Text -Type "done" -Text "Group membership set to `$group."

        if (`$group -eq "Administrators") { `$groupType = "An administrator" } else { `$groupType = "A standard user" }

        Write-CloseOut "`$groupType was created with the username '`$name'." -Script "Add-LocalUser"
    } catch {
        Write-Text -Type "error" -Text "Add User Error: `$(`$_.Exception.Message)"
        Read-Host "   Press any key to continue"
    }
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $addLocalUser
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Initialize-Script '$Script'"

PowerShell.exe -File "$path\$Script.ps1" -Verb RunAs