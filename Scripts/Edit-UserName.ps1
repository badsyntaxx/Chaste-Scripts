if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}
    

function Edit-UserName {
    try {
        $scriptDescription = @"
 This script allows you to modify the username of a user on a Windows system. 
"@

        Get-Item -ErrorAction SilentlyContinue "$scriptPath\Edit-UserName.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host " Chaste Scripts: Edit User Name v0315242300"
        Write-Host "$scriptDescription" -ForegroundColor DarkGray

        $username = Select-User

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