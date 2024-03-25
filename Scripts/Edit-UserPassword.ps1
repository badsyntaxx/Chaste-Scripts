if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
} 

function Edit-UserPassword {
    try {
        Write-Welcome -Title "Edit User Password" -Description "Edit an existing users Password." -Command "edit user password"

        $username = Select-User

        Write-Text -Type "header" -Text "Enter password or leave blank" -LineBefore -LineAfter
        
        $password = Get-Input -Prompt "" -IsSecure $true

        if ($password.Length -eq 0) { $alert = "## You're about to remove this users password." } 
        else { $alert = "## You're about to change this users password." }

        Write-Text -Type "notice" -Text $alert -LineBefore -LineAfter

        $options = @(
            "Submit  - Confirm and apply." 
            "Reset   - Start over at the beginning."
            "Exit    - Run a different command."
        )

        $choice = Get-Option -Options $options -LineAfter
        if ($choice -ne 0 -and $choice -ne 1 -and $choice -ne 2) { Edit-UserPassword }
        if ($choice -eq 1) { Invoke-Script "Edit-UserPassword" }
        if ($choice -eq 2) { Write-Exit -Script "Edit-UserPassword" }

        Get-LocalUser -Name $Username | Set-LocalUser -Password $password

        Write-Exit -Message "The password for this account has been changed." -Script "Edit-UserPassword"
    } catch {
        Write-Text -Type "error" -Text "Edit password error: $($_.Exception.Message)"
        Write-Exit -Script "Edit-UserPassword"
    }
}

