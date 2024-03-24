if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

function Add-LocalUser {
    try {
        $scriptDescription = @"
 This function creates a new local user account on a Windows system with specified settings, 
 including the username, optional password, and group. The account and password never expire.
"@
        Write-Welcome -Title "Add User v0315241122" -Description $scriptDescription

        Write-Text -Type "header" -Text "Enter name" -LineBefore -LineAfter
        $name = Get-Input -Validate "^([a-zA-Z0-9 _\-]{1,64})$"  -CheckExistingUser

        Write-Text -Type "header" -Text "Enter password" -LineBefore -LineAfter
        $password = Get-Input -IsSecure
        
        Write-Text -Type "header" -Text "Set group membership" -LineBefore -LineAfter
        $group = Get-Option -Options $([ordered]@{
                'Administrators' = 'Set this users group membership to administrators.'
                'Users'          = 'Set this users group membership to standard users.' 
            }) -ReturnValue -LineAfter

        Write-Text -Type "notice" -Text "You're about to create a new local user!" -LineAfter
        $choice = Get-Option -Options $([ordered]@{
                "Submit" = "Confirm and apply." 
                "Reset"  = "Start over at the beginning."
                "Exit"   = "Run a different command."
            }) -LineAfter

        if ($choice -ne 0 -and $choice -ne 2) { Invoke-Script "Add-LocalUser" }
        if ($choice -eq 2) { Write-Exit -Script "Add-LocalUser" }

        New-LocalUser $name -Password $password -Description "Local User" -AccountNeverExpires -PasswordNeverExpires -ErrorAction Stop | Out-Null
        Add-LocalGroupMember -Group $group -Member $name -ErrorAction Stop

        $newUserName = Get-LocalUser -Name $name | Select-Object -ExpandProperty Name
        $data = Get-UserData $newUserName

        Write-Text -Type "list" -List $data -LineAfter

        if ($null -ne $newUserName) { Write-Exit -Message "The user account was created." -Script "Add-LocalUser" } 
        else { throw "There was an unknown error when creating the user." }
    } catch {
        Write-Text -Type "error" -Text "Add local user error: $($_.Exception.Message)"
        Write-Exit
    }
}
