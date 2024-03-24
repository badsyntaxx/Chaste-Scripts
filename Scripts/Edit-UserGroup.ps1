
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

function Edit-UserGroup {
    try {
        Write-Welcome -Title "Edit User Group" -Description "Edit an existing users group membership." -Command "edit user group"

        $username = Select-User

        Write-Text -Type "header" -Text "Select user group" -LineBefore -LineAfter
     
        $groups = Get-LocalGroup | ForEach-Object {
            $description = $_.Description
            if ($description.Length -gt 72) {
                $description = $description.Substring(0, 72) + "..."
            }
            @{ $_.Name = $description }
        } | Sort-Object -Property Name
        
        $moreGroups = [ordered]@{}

        foreach ($group in $groups) {
            $moreGroups += $group
        }
        
        $group = Get-Option -Options $moreGroups -ReturnValue
        
        $data = Get-UserData -Username $username

        Write-Text -Type "notice" -Text "You're about to change this users group membership." -LineBefore -LineAfter
        $choice = Get-Option -Options $([ordered]@{
                "Submit" = "Confirm and apply." 
                "Reset"  = "Start over at the beginning."
                "Exit"   = "Run a different command."
            }) -LineAfter

        if ($choice -ne 0 -and $choice -ne 1 -and $choice -ne 2) { $script }
        if ($choice -eq 1) { Invoke-Script "Edit-UserGroup" }
        if ($choice -eq 2) { Write-Exit -Script "Edit-UserGroup" }

        Remove-LocalGroupMember -Group "Administrators" -Member $username -ErrorAction SilentlyContinue

        Add-LocalGroupMember -Group $group -Member $username -ErrorAction SilentlyContinue | Out-Null

        $data = Get-UserData $username

        Write-Text -Type "list" -List $data -LineAfter

        Write-Exit "The group membership for $username has been changed to $group." -Script "Edit-UserGroup"
    } catch {
        Write-Text -Type "error" -Text "Edit group error: $($_.Exception.Message)"
        Write-Exit -Script "Edit-UserGroup"
    }
} 
