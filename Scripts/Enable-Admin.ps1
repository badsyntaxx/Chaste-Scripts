if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

function Enable-Admin {
    try { 
        $scriptDescription = @"
 This script allows you to toggle the built in admin account on a Windows system. 
 It provides an interactive menu for you to enable or disable the account.
"@

        Write-Welcome -Title "Enable Administrator v0315241122" -Description `"$scriptDescription`"

        Write-Text -Type "header" -Text "Toggle admin account" -LineBefore -LineAfter
        $admin = Get-LocalUser -Name "Administrator"

        Write-Host "    Administrator:" -NoNewLine

        if ($admin.Enabled) { Write-Host "Enabled" -ForegroundColor Yellow } 
        else { Write-Host "Disabled" -ForegroundColor Yellow }
        
        $choice = Get-Option -Options $([ordered]@{
                "Enable"  = "Enable the Windows built in administrator account."
                "Disable" = "Disable the built in administrator account."
            }) -LineAfter -LineBefore

        if ($choice -ne 0 -and $choice -ne 1) { Enable-Admin }

        if ($choice -eq 0) { 
            Get-LocalUser -Name "Administrator" | Enable-LocalUser 
            $message = "Administrator account enabled."
        } 

        if ($choice -eq 1) { 
            Get-LocalUser -Name "Administrator" | Disable-LocalUser 
            $message = "Administrator account Disabled."
        }

        Write-Exit -Message $message -Script "Enable-Admin"
    } catch {
        Write-Text -Type "error" -Text "Enable admin error: $($_.Exception.Message)"
        Write-Exit -Script "Enable-Admin"
    }
}