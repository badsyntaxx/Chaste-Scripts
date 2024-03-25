function Edit-UserPassword {
    try {
        Write-Welcome -Title "Edit User Password" -Description "Edit an existing users Password." -Command "edit user password"

        $username = Select-User
        $data = Get-UserData -Username $username

        if ($data["Source"] -eq "Local") { Edit-LocalUserName -Source $data["Source"] } else { Edit-ADUserName }
    } catch {
        Write-Text -Type "error" -Text "Edit password error: $($_.Exception.Message)"
        Write-Exit -Script "Edit-UserPassword"
    }
}

function EditLocalUserPassword {
    try {
        Write-Text -Type "header" -Text "Enter password or leave blank" -LineBefore -LineAfter
        $password = Get-Input -Prompt "" -IsSecure $true

        if ($password.Length -eq 0) { $alert = "## You're about to remove this users password." } 
        else { $alert = "## You're about to change this users password." }

        Write-Text -Type "notice" -Text $alert -LineBefore -LineAfter
        $choice = Get-Option -Options $([ordered]@{
                "Submit" = "Confirm and apply." 
                "Reset"  = "Start over at the beginning."
                "Exit"   = "Run a different command."
            }) -LineAfter
            
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

function Edit-ADUserPassword {
    Write-Text -Type "fail" -Text "Editing domain users doesn't work yet."
    Write-Exit
}