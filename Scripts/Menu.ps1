function Menu {
    $scriptDescription = @"
 This is the Chaste Scripts menu. Here you can select the various functions without
 typing out commands.
"@

    Write-Welcome -Title "Menu v0323241029" -Description "$scriptDescription"

    Write-Text -Type "header" -Text "Selection" -LineAfter -LineBefore
    $choice = Get-Option -Options $([ordered]@{
            "Enable administrator" = "Toggle the Windows built in administrator account."
            "Add user"             = "Add a user to the system."
            "Remove user"          = "Remove a user from the system."
            "Edit user name"       = "Edit a users name."
            "Edit user password"   = "Edit a users password."
            "Edit user group"      = "Edit a users group membership."
            "Edit hostname"        = "Edit this computers name and description."
            "Edit network adapter" = "Edit a network adapter.(beta)"
        })

    if ($choice -eq 0) { $script = "Enable-Admin" }
    if ($choice -eq 1) { $script = "Add-User" }
    if ($choice -eq 2) { $script = "Remove-User" }
    if ($choice -eq 3) { $script = "Edit-UserName" }
    if ($choice -eq 4) { $script = "Edit-UserPassword" }
    if ($choice -eq 5) { $script = "Edit-UserGroup" }
    if ($choice -eq 6) { $script = "Edit-Hostname" }
    if ($choice -eq 7) { $script = "Edit-NetworkAdapter" }

    Write-Text -Text "Initializing script..." -LineBefore
    
    Get-Script -Url "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-$script.ps1" -Target "$env:TEMP\CS-Menu.ps1"

    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$env:TEMP\CS-Menu.ps1`"" -WorkingDirectory $pwd -Verb RunAs
}