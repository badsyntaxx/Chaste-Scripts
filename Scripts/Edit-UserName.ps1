function Edit-UserName {
    try {
        Write-Welcome -Title "Edit User Name" -Description "Edit an existing users name." -Command "edit user name"

        $username = Select-User
        $data = Get-UserData -Username $username

        if ($data["Source"] -eq "Local") { Edit-LocalUserName -Source $data["Source"] } else { Edit-ADUserName }
    } catch {
        Write-Text -Type "error" -Text "Edit name error: $($_.Exception.Message)"
        Write-Exit -Script "Edit-UserName"
    }
}

function Edit-LocalUserName {
    try {
        Write-Text -Type "header" -Text "Enter username" -LineBefore -LineAfter
        $newName = Get-Input -Prompt "" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser

        Write-Text -Type "notice" -Text "You're about to change this users name." -LineBefore -LineAfter
        $choice = Get-Option -Options $([ordered]@{
                "Submit" = "Confirm and apply." 
                "Reset"  = "Start over at the beginning."
                "Exit"   = "Run a different command."
            }) -LineAfter

        if ($choice -ne 0 -and $choice -ne 1 -and $choice -ne 2) { Edit-UserName }
        if ($choice -eq 1) { Invoke-Script "Edit-UserName" }
        if ($choice -eq 2) { Write-Exit -Script "Edit-UserName" }
    
        Rename-LocalUser -Name $username -NewName $newName

        $newUser = Get-LocalUser -Name $newName

        if ($null -ne $newUser) { 
            $data = Get-UserData $newName
            Write-Text -Type "list" -List $data -LineAfter
            Write-Exit "The name for this account has been changed." -Script "Edit-UserName"
        } else {
            Write-Text -Type "fail" -Text "There was an unknown error when trying to rename this user."
        }
    } catch {
        Write-Text -Type "error" -Text "Edit name error: $($_.Exception.Message)"
        Write-Exit -Script "Edit-UserName"
    }
}

function Edit-ADUserName {
    Write-Text -Type "fail" -Text "Editing domain users doesn't work yet."
    Write-Exit
}