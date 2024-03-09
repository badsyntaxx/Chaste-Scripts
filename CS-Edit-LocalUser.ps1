if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
    Exit;
} 

$Script = "Edit-LocalUser"
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
function Edit-LocalUser {
    Write-Host "Chaste Scripts: Edit Local User" -ForegroundColor DarkGray
    Write-Text -Type "header" -Text "Select a user" -LineBefore

    `$accountNames = @()
    `$localUsers = Get-LocalUser
    `$excludedAccounts = @("DefaultAccount", "Administrator", "WDAGUtilityAccount", "Guest", "defaultuser0")

    foreach (`$user in `$localUsers) {
        if (`$user.Name -notin `$excludedAccounts) { `$accountNames += `$user.Name }
    }

    `$choice = Get-Option -Options `$accountNames

    Select-Action -Username `$accountNames[`$choice]
}

function Select-Action {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Username
    )

    Write-Text -Type "header" -Text "Select an action" -LineBefore

    `$data = Get-AccountInfo `$Username

    Write-Text -Type "recap" -Data `$data -LineAfter

    `$options = @(
        "Change / remove password   - Change or remove the password.",
        "Edit username              - Edit the account username.",
        "Change group               - Edit group membership (Administrators / Users).",
        "Delete account             - Delete the local user account.",
        "Go back                    - Go back to user selection."
    )

    `$script:confirmation = @(
        "Submit   - Confirm and apply changes", 
        "Reset    - Start edit user over.", 
        "Exit     - Start over back at task selection."
    )
    
    `$choice = Get-Option -Options `$options

    switch (`$choice) {
        0 { Set-Password -Username `$Username }
        1 { Set-Name -Username `$Username }
        2 { Set-Group -Username `$Username }
        3 { Remove-User -Username `$Username }
        4 { Invoke-Script "Edit-LocalUser" }  # Go back to account selection
    }
}

function Set-Password {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Username
    )

    try {
        Write-Text -Type "header" -Text "Change password" -LineBefore
        Write-Text -Type "notice" -Text "NOTICE: Leave blank to remove password."
        `$password = Get-Input -Prompt "Password" -IsSecure `$true

        if (`$password.Length -eq 0) { `$alert = "NOTICE: You're about to remove this users password." } 
        else { `$alert = "NOTICE: You're about to change this users password." }

        Write-Text -Type "header" -Text "Confirm password change" -LineBefore

        `$data = Get-AccountInfo `$Username

        Write-Text -Type "notice" -Text "`$alert"
        Write-Text -Type "recap" -Data `$data -LineAfter

        `$choice = Get-Option -Options `$confirmation
        if (`$choice -ne 0 -and `$choice -ne 1 -and `$choice -ne 2) { Set-Password }
        if (`$choice -eq 1) { Invoke-Script "Edit-LocalUser" }
        if (`$choice -eq 2) { Write-CloseOut -Script "Edit-LocalUser" }

        `$account = Get-LocalUser -Name `$Username
        `$account | Set-LocalUser -Password `$password

        Write-Host
        Write-CloseOut -Message "The password for this account has been changed." -Script "Edit-LocalUser"
    } catch {
        Write-Text -Type "error" -Text "Set Password Error: `$(`$_.Exception.Message)"
        Read-Host -Prompt "Press any key to continue"
    }
}

function Set-Name {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Username
    )

    try {
        Write-Text -Type "header" -Text "Change username" -LineBefore

        `$newName = Get-Input -Prompt "Username" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser

        Write-Text -Type "header" -Text "Confirm name change" -LineBefore

        `$data["New Name"] = `$newName 

        Write-Text -Type "notice" -Text "NOTICE: You're about to change this users name."
        Write-Text -Type "recap" -Data `$data -LineAfter

        `$choice = Get-Option -Options `$confirmation
        if (`$choice -ne 0 -and `$choice -ne 1 -and `$choice -ne 2) { Set-Name }
        if (`$choice -eq 1) { Invoke-Script "Edit-LocalUser" }
        if (`$choice -eq 2) { Write-CloseOut -Script "Edit-LocalUser" }
    
        Rename-LocalUser -Name `$Username -NewName `$newName

        Write-CloseOut "The name for this account has been changed." -Script "Edit-LocalUser"
    } catch {
        Write-Text -Type "error" -Text "Set Name Error: `$(`$_.Exception.Message)"
        Read-Host -Prompt "Press any key to continue"
    }
}

function Set-Group {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Username
    )

    try {
        Write-Text -Type "header" -Text "Change group membership" -LineBefore

        `$options = @(
            "Administrator  - Make this user an administrator."
            "Standard User  - Make this user a standard user."
            "Back           - Go back to action selection."
        )

        `$group = Get-Option -Options `$options

        switch (`$group) {
            0 { `$group = 'Administrators' }
            1 { `$group = 'Users' }
            2 { Select-Action -Username `$Username }
        }

        Write-Text -Type "header" -Text "Confirm group change" -LineBefore

        Write-Text -Type "notice" -Text "NOTICE: You're about to change this users group membership."
        Write-Text -Type "recap" -Data `$data -LineAfter
        
        `$choice = Get-Option -Options `$confirmation

        if (`$choice -ne 0 -and `$choice -ne 1 -and `$choice -ne 2) { Set-Group }
        if (`$choice -eq 1) { Invoke-Script "Edit-LocalUser" }
        if (`$choice -eq 2) { Write-CloseOut -Script "Edit-LocalUser" }

        Remove-LocalGroupMember -Group "Administrators" -Member `$Username -ErrorAction SilentlyContinue
        Add-LocalGroupMember -Group `$group -Member `$Username
        
        Write-CloseOut "The group membership for `$Username has been changed to `$group." -Script "Edit-LocalUser"
    } catch {
        Write-Text -Type "error" -Text "Set Group Error: `$(`$_.Exception.Message)"
        Read-Host -Prompt "Press any key to continue"
    }
} 

function Remove-User {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Username
    )

    try {
        Write-Text -Type "header" -Text "Delete user data" -LineBefore
        `$options = @(
            "Delete  - Also delete the users data.",
            "Keep    - Do not delete the users data."
            "Back    - Go back to action selection."
        )

        `$choice = Get-Option -Options `$options
        if (`$choice -eq 0) { `$deleteData = `$true }
        if (`$choice -eq 1) { `$deleteData = `$false }
        if (`$choice -eq 2) { Select-Action -Username `$Username }

        Write-Text -Type "header" -Text "Confirm user deletion" -LineBefore
        if (`$deleteData) {
            Write-Text -Type "notice" "NOTICE: You're about to delete this account and it's data!"
        } else {
            Write-Text -Type "notice"  "NOTICE: You're about to delete this account!"
        }

        `$data = Get-AccountInfo `$Username

        Write-Text -Type "recap" -Data `$data -LineAfter
        
        `$choice = Get-Option -Options `$confirmation
        if (`$choice -ne 0 -and `$choice -ne 2) { Invoke-Script "Edit-LocalUser" }
        if (`$choice -eq 2) { Write-CloseOut -Script "Edit-LocalUser" }

        Remove-LocalUser -Name `$Username

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

        Write-CloseOut "The user has been deleted." -Script "Edit-LocalUser"
    } catch {
        Write-Text -Type "error" -Text "Remove User Error: `$(`$_.Exception.Message)"
        Read-Host -Prompt "   Press any key to continue"
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