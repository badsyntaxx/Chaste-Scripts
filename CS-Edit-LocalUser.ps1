if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
    Exit;
} 

$Script = "Edit-LocalUser"
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
$path = if ($isAdmin) { "$env:SystemRoot\Temp" } else { "$env:TEMP" }

$framework = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/badsyntaxx/Chases-Windows-Scripts/main/CWS-Framework.ps1"
$framework = Get-Content -Path "C:\Users\Chase Asahina\Desktop\Chases-Windows-Scripts\CWS-Framework.ps1" -Raw

$editLocalUser = @"
function Edit-LocalUser {
    Write-Host "Chase's Windows Tools: Edit Local User" -ForegroundColor DarkGray
    Select-LocalUser
}


function Select-LocalUser {
    Write-Text -Type "subheading" -Text "Select a user" -LineBefore
    `$accountNames = @()
    `$localUsers = Get-LocalUser
    `$excludedAccounts = @("DefaultAccount", "Administrator", "WDAGUtilityAccount", "Guest", "defaultuser0")
    `$script:confirmOptions = @(
        "Submit   - Confirm and apply changes", 
        "Reset    - Start edit user over.", 
        "Exit     - Start over back at task selection."
    )

    foreach (`$user in `$localUsers) {
        if (`$user.Name -notin `$excludedAccounts) { `$accountNames += `$user.Name }
    }

    `$choice = Get-Option -Options `$accountNames

    Select-LocalUserAction -Username `$accountNames[`$choice]
}

function Select-LocalUserAction {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Username
    )

    Write-Text "Select an action" -Type "subheading" -LineBefore

    `$options = @(
        "Change / remove password   - Change or remove the password.",
        "Edit username              - Edit the account username.",
        "Change group               - Edit group membership (Administrators / Users).",
        "Delete account             - Delete the local user account.",
        "Go back                    - Go back to account selection."
    )
    
    `$choice = Get-Option -Options `$options

    switch (`$choice) {
        0 { Set-Password -Username `$Username }
        1 { Set-Name -Username `$Username }
        2 { Set-Group -Username `$Username }
        3 { Remove-Account -Username `$Username }
        4 { Select-LocalUser }  # Go back to account selection
    }
}

function Set-Password {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Username
    )

    try {
        Write-Text "Change password" -Type "subheading" -LineBefore

        `$password = Get-Input -Prompt "Enter password or leave blank" -IsSecure `$true
        `$pwString = ""

        if (`$password.Length -eq 0) {
            `$alert = "NOTICE: You're about to remove this users password."
        } else {
            `$alert = "NOTICE: You're about to change this users password."
            for (`$i = 0; `$i -lt `$password.Length; `$i++) { `$pwString += "*" }
        }

        Write-Text "Confirm password change" -Type "subheading" -LineBefore
        `$data = Get-AccountInfo `$Username
        Write-Recap `$data
        Write-Text -Text "`$alert" -Type "notice" -LineBefore -LineAfter
        `$choice = Get-Option -Options `$confirmOptions

        if (`$choice -ne 0 -and `$choice -ne 1 -and `$choice -ne 2) { Set-Password }
        if (`$choice -eq 1) { Select-LocalUser }
        if (`$choice -eq 2) { Invoke-RestMethod https://chaste.dev/s | Invoke-Expression }

        `$account = Get-LocalUser -Name `$Username
        `$account | Set-LocalUser -Password `$password

        Write-Host
        Write-CloseOut "The password for this account has been changed." -Script "Edit-LocalUser"
    } catch {
        Write-Text -Text "Set Password Error: `$(`$_.Exception.Message)" -Type "error"
        Read-Host -Prompt "Press any key to continue"
    }
}

function Set-Name {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Username
    )

    try {
        `$data = Get-AccountInfo `$Username
        `$data["Select Action"] = "Edit User name."
        `$newName = Get-Input -SubHeading "New Name" -Prompt "Enter new name" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,15})$" -Data `$data
        `$data["New Name"] = `$newName 
        `$choice = Get-Option -SubHeading "Confrim Name Change" -Options `$confirmOptions -Alert "NOTICE: You're about to change this users name." -Data `$data

        switch (`$choice) {
            1 { 
                Rename-LocalUser -Name `$Username -NewName `$newName

                Write-WrapUp -SubHeading "Confirm Name Change" -Data `$data -Alert "The name for this account has been changed."
            }
            2 { Select-LocalUser }
            3 { Invoke-RestMethod https://chaste.dev/s | Invoke-Expression }
            Default { Set-Name }
        }
    } catch {
        Write-Alert -Text "ERROR: `$(`$_.Exception.Message)" -Type "error"
        Read-Host -Prompt "Press any key to continue"
    }
}

function Set-Group {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Username
    )

    try {
        `$data = Get-AccountInfo `$Username
        `$options = @("Administrator", "Standard User")
        `$group = Get-Option -SubHeading "Select Group Membership" -Options `$options -Data `$data

        switch (`$group) {
            1 { `$group = 'Administrators' }
            2 { `$group = 'Users' }
        }
        
        `$data["Select Group Membership"] = `$group 
        `$choice = Get-Option -SubHeading "Confrim Group Change" -Options `$confirmOptions -Alert "NOTICE: You're about to change the group membership for '`$Username'." -Data `$data

        switch (`$choice) {
            1 { 
                Remove-LocalGroupMember -Group "Administrators" -Member `$Username -ErrorAction SilentlyContinue
                Add-LocalGroupMember -Group `$group -Member `$Username
                
                Write-WrapUp -SubHeading "Confrim Group Change" -Data `$data -Alert "The group membership for `$Username has been changed to `$group."
            }
            2 { Select-LocalUser }
            3 { Invoke-RestMethod https://chaste.dev/s | Invoke-Expression }
            Default { Set-Group }
        }
    } catch {
        Write-Alert -Text "ERROR: `$(`$_.Exception.Message)" -Type "error"
        Read-Host -Prompt "Press any key to continue"
    }
} 

function Remove-Account {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Username
    )

    try {
        Write-Text "Delete user data" -Type "subheading" -LineBefore
        `$options = @(
            "Delete data - Also delete the users data and remove their profile folder",
            "Keep data - Do not delete the users data and leave their profile folder alone"
        )

        `$choice = Get-Option -Options `$options

        `$data = Get-AccountInfo `$Username
        `$deleteData = `$false
        if (`$choice -eq 0) { `$deleteData = `$true }

        Write-Text "Confirm user deletion" -Type "subheading" -LineBefore
        Write-Recap -Data `$data
        if (`$deleteData) {
            Write-Text "NOTICE: You're about to delete this account and it's data!" -Type "notice" -LineBefore
        } else {
            Write-Text "NOTICE: You're about to delete this account!" -Type "notice" -LineBefore
        }
        

        `$choice = Get-Option -Options `$confirmOptions

        if (`$choice -ne 0 -and `$choice -ne 2) { Select-LocalUser }
        if (`$choice -eq 2) { Invoke-RestMethod https://chaste.dev/s | Invoke-Expression }

        Remove-LocalUser -Name `$Username
        Write-Text "Local user removed." -Type "done" -LineBefore
        if (`$deleteData) {
            `$userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '`$(`$user.SID)'"
            `$dir = `$userProfile.LocalPath
            if (`$null -ne `$dir -And (Test-Path -Path `$dir)) { 
                Remove-Item -Path `$dir -Recurse -Force 
                Write-Text "User data deleted." -Type "done"
            } else {
                Write-Text "No data found."
            }
        }

        Write-CloseOut "User account with the name '`$Username' has been deleted." -Script "Edit-LocalUser"
    } catch {
        Write-Text -Text "Account Removal Error: `$(`$_.Exception.Message)" -Type "error"
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
        Write-Alert -Text "ERROR: `$(`$_.Exception.Message)" -Type "error"
        Read-Host -Prompt "Press any key to continue"
    }
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $editLocalUser
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Initialize-Script '$Script'"

PowerShell.exe -File "$path\$Script.ps1" -Verb RunAs