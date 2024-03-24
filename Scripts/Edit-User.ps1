
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

function Edit-User {
    try {
        $scriptDescription = @"
 This function creates a new local user account on a Windows system with specified settings, 
 including the username, optional password, and group. The account and password never expire.
"@

        Write-Welcome -Title "Edit User v0315241122" -Description $scriptDescription

        Write-Text -Type "header" -Text "What type of edit would you like to make?" -LineBefore -LineAfter
        $choice = Get-Option -Options $([ordered]@{
                'Edit user name'     = 'Edit a local users name.'
                'Edit user password' = 'Edit a local users password.'
                'Edit user group'    = 'Edit a local users group.'
            })

        if ($choice -eq 0) { irm chaste.dev/edit/user/name | iex }
        if ($choice -eq 1) { irm chaste.dev/edit/user/password | iex }
        if ($choice -eq 2) { irm chaste.dev/edit/user/group | iex }
    } catch {
        Write-Text -Type "error" -Text "Edit user error: $($_.Exception.Message)"
        Write-Exit -Script "Edit-User"
    }
}