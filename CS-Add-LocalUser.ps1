if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
    Exit;
} 

$Script = "Add-LocalUser"
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
$path = if ($isAdmin) { "$env:SystemRoot\Temp" } else { "$env:TEMP" }
$framework = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/badsyntaxx/Chases-Windows-Scripts/main/CWS-Framework.ps1"
$framework = Get-Content -Path "C:\Users\Chase Asahina\Desktop\Chases-Windows-Scripts\CWS-Framework.ps1" -Raw

$addLocalUser = @"
function Add-LocalUser {
    try {
        Write-Host "Chase's Windows Tools: Create Local User`n`n" -ForegroundColor DarkGray
        Write-Text -Text "Credentials" -Type "subheading"
        `$data = [ordered]@{}
        `$name = Get-Input -Prompt "Username" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,15})$" 
        `$account = Get-LocalUser -Name `$name -ErrorAction SilentlyContinue

        while (`$null -ne `$account) {
            `$name = Get-Input -Prompt "Username" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,15})$" -Alert "ERROR: An account with that name already exists." -AlertType "error"
            `$account = Get-LocalUser -Name `$name -ErrorAction SilentlyContinue
        }

        `$data["Name"] = `$name
        `$password = Get-Input -Prompt "Password" -IsSecure `$true 
        `$pwString = ""
        for (`$i = 0; `$i -lt `$password.Length; `$i++) { `$pwString += "*" }
        `$data["Password"] = `$pwString

        Write-Text -Type "subheading" -Text "Group membership" -LineBefore
        `$choice = Get-Option -Options @("Administrator", "Standard user")
        if (`$choice -eq 0) { `$group = 'Administrators' } else { `$group = "Users" }
        if (`$group -eq 'Administrators') { `$groupDisplay = 'Administrator' } else { `$groupDisplay = 'Standard user' }

        `$options = @(
            "Submit   - Confirm and apply changes", 
            "Reset    - Start add user over.", 
            "Exit     - Start over back at task selection."
        )

        `$data["Group"] = `$groupDisplay 

        Write-Text "Confirm user settings" -Type "subheading" -LineBefore
        Write-Recap -Data `$data
        Write-Text -Type "notice" -Text "NOTICE: You're about to create a new local user!" -LineAfter -LineBefore

        `$choice = Get-Option -Options `$options
        switch (`$choice) {
            0 { 
                Write-Text -Type "subheading" -Text "Create local user" -LineBefore
                New-LocalUser `$name -Password `$password -Description "Local User" -AccountNeverExpires -PasswordNeverExpires -ErrorAction Stop | Out-Null
                Write-Text -Type "done" -Text "Local user created."
                Add-LocalGroupMember -Group `$group -Member `$name -ErrorAction Stop
                Write-Text -Type "done" -Text "Group membership set to `$group."

                if (`$group -eq "Administrators") { `$groupType = "An administrator" } else { `$groupType = "A standard user" }

                Write-CloseOut "`$groupType was created with the username '`$name'." -Script "Add-LocalUser"
            }
            2 { Invoke-RestMethod https://chaste.dev/s | Invoke-Expression }
            Default { Add-NewLocalUser }
        }
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