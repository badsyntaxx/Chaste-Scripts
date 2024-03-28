function Edit-UserGroup {
    try {
        Write-Welcome -Title "Edit User Group" -Description "Edit an existing users group membership." -Command "edit user group"

        $username = Select-User
        $data = Get-UserData -Username $username

        if ($data["Source"] -eq "Local") { Edit-LocalUserGroup -Source $data["Source"] } else { Edit-ADUserGroup }
    } catch {
        Write-Text -Type "error" -Text "Edit group error: $($_.Exception.Message)"
        Write-Exit -Script "Edit-UserGroup"
    }
} 

function Edit-LocalUserGroup {
    param (
        [Parameter(Mandatory)]
        [string]$Source
    )

    try {
        Write-Text -Type "header" -Text "Add or Remove user from groups" -LineBefore -LineAfter
        $addOrRemove = Get-Option -Options $([ordered]@{
                "Add"    = "Add this user to more groups"
                "Remove" = "Remove this user from certain groups"
            }) -ReturnKey

        Write-Text -Type "header" -Text "Select user group" -LineBefore -LineAfter
        $groups = Get-LocalGroup | ForEach-Object {
            $description = $_.Description
            if ($description.Length -gt 72) { $description = $description.Substring(0, 72) + "..." }
            @{ $_.Name = $description }
        } | Sort-Object -Property Name
    
        $moreGroups = [ordered]@{}

        foreach ($group in $groups) { 
            $moreGroups += $group
            switch ($group.Keys) {
                "Performance Monitor Users" { $moreGroups["$($group.Keys)"] = "Access local performance counter data." }
                "Power Users" { $moreGroups["$($group.Keys)"] = "Limited administrative privileges." }
                "Network Configuration Operators" { $moreGroups["$($group.Keys)"] = "Privileges for managing network configuration." }
                "Performance Log Users" { $moreGroups["$($group.Keys)"] = "Schedule performance counter logging." }
                "Remote Desktop Users" { $moreGroups["$($group.Keys)"] = "Log on remotely." }
                "System Managed Accounts Group" { $moreGroups["$($group.Keys)"] = "Managed by the system." }
                "Users" { $moreGroups["$($group.Keys)"] = "Prevented from making system-wide changes." }
                "Remote Management Users" { $moreGroups["$($group.Keys)"] = "Access WMI resources over management protocols." }
                "Replicator" { $moreGroups["$($group.Keys)"] = "Supports file replication in a domain." }
                "IIS_IUSRS" { $moreGroups["$($group.Keys)"] = "Used by Internet Information Services (IIS)." }
                "Backup Operators" { $moreGroups["$($group.Keys)"] = "Override security restrictions for backup purposes." }
                "Cryptographic Operators" { $moreGroups["$($group.Keys)"] = "Perform cryptographic operations." }
                "Access Control Assistance Operators" { $moreGroups["$($group.Keys)"] = "Remotely query authorization attributes and permissions." }
                "Administrators" { $moreGroups["$($group.Keys)"] = "Complete, unrestricted access to the computer/domain." }
                "Device Owners" { $moreGroups["$($group.Keys)"] = "Can change system-wide settings." }
                "Guests" { $moreGroups["$($group.Keys)"] = "Similar access to members of the Users group by default." }
                "Hyper-V Administrators" { $moreGroups["$($group.Keys)"] = "Complete and unrestricted access to all Hyper-V features." }
                "Distributed COM Users" { $moreGroups["$($group.Keys)"] = "Authorized for Distributed Component Object Model (DCOM) operations." }
            }
        }
    
        $selectedGroups = @()
        $selectedGroups += Get-Option -Options $moreGroups -ReturnKey

        $moreGroupsDone = [ordered]@{}
        $moreGroupsDone["Done"] = "Stop selecting groups and move to the next step."
        $moreGroupsDone += $moreGroups
        $previewString = ""

        while ($selectedGroups -notcontains 'Done') {
            $previewString = $selectedGroups -join ","
            Write-Text -Type "header" -Text "$previewString" -LineBefore -LineAfter
            $selectedGroups += Get-Option -Options $moreGroupsDone -ReturnKey 
        }

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

        foreach ($group in $selectedGroups) {
            if ($addOrRemove -eq "Add") {
                Add-LocalGroupMember -Group $group -Member $username -ErrorAction SilentlyContinue | Out-Null 
            } else {
                Remove-LocalGroupMember -Group $group -Member $username -ErrorAction SilentlyContinue
            }
        }

        $data = Get-UserData $username

        Write-Text -Type "list" -List $data -LineAfter
        Write-Exit "The group membership for $username has been changed to $group." -Script "Edit-UserGroup"
    } catch {
        Write-Text -Type "error" -Text "Edit local group error: $($_.Exception.Message)"
        Write-Exit -Script "Edit-UserGroup"
    }
}

function Edit-ADUserGroup {
    Write-Text -Type "fail" -Text "Editing domain users doesn't work yet."
    Write-Exit
}

