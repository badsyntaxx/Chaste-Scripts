function Enable-Admin {
    try { 
        Write-Welcome -Title "Toggle Administrator" -Description "Toggle the built-in administrator account." -Command "enable admin"

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

