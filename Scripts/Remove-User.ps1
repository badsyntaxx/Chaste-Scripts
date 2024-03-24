if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

function Remove-User {
    try {
        $scriptDescription = @"
 This function allows you to remove a user from a Windows system, with options 
 to delete or keep their user profile / data.
"@
        Write-Welcome  -Title "Remove User v0315241122" -Description $scriptDescription

        $username = Select-User

        Write-Text -Type "header" -Text "Delete user data" -LineBefore -LineAfter
        $choice = Get-Option -Options $([ordered]@{
                "Delete" = "Also delete the users data."
                "Keep"   = "Do not delete the users data."
            }) -LineAfter

        if ($choice -eq 0) { $deleteData = $true }
        if ($choice -eq 1) { $deleteData = $false }

        if ($deleteData) {
            Write-Text -Type "notice" "You're about to delete this account and it's data!" -LineBefore -LineAfter
        } else {
            Write-Text -Type "notice" "You're about to delete this account!" -LineBefore -LineAfter
        }
        
        $choice = Get-Option -Options $([ordered]@{
                "Submit" = "Confirm and apply." 
                "Reset"  = "Start over at the beginning."
                "Exit"   = "Run a different command."
            }) -LineAfter

        if ($choice -ne 0 -and $choice -ne 2) { Invoke-Script "Remove-User" }
        if ($choice -eq 2) { Write-Exit -Script "Remove-User" }

        Remove-LocalUser -Name $username | Out-Null

        $user = Get-LocalUser -Name $username -ErrorAction SilentlyContinue | Out-Null

        if ($null -eq $user) {
            Write-Text -Type "done" -Text "Local user removed."
        } else {
            Write-Text -Type "fail" -Text "Local user not removed." -LineBefore
        }
        
        if ($deleteData) {
            $userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '$($user.SID)'"
            $dir = $userProfile.LocalPath
            if ($null -ne $dir -And (Test-Path -Path $dir)) { 
                Remove-Item -Path $dir -Recurse -Force 
                Write-Text -Type "done" -Text "User data deleted."
            } else {
                Write-Text -Type "done" -Text "No data found." -LineAfter
            }
        }

        Write-Exit -Message "The user has been deleted." -LineBefore -LineAfter -Script "Remove-User"
    } catch {
        Write-Text -Type "error" -Text "Remove User Error: $($_.Exception.Message)"
        Write-Exit -Script "Remove-User"
    }
}