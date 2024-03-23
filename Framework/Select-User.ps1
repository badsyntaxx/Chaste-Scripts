function Select-User {
    try {
        Write-Text -Type "header" -Text "Select a user" -LineBefore -LineAfter

        $userNames = @()
        $localUsers = Get-LocalUser
        $excludedAccounts = @("DefaultAccount", "WDAGUtilityAccount", "Guest", "defaultuser0")
        $adminEnabled = Get-LocalUser -Name "Administrator" | Select-Object -ExpandProperty Enabled

        if (!$adminEnabled) { $excludedAccounts += "Administrator" }

        foreach ($user in $localUsers) {
            if ($user.Name -notin $excludedAccounts) { $userNames += $user.Name }
        }

        $accounts = [ordered]@{}
        foreach ($name in $userNames) {
            $username = Get-LocalUser -Name $name
            $groups = Get-LocalGroup | Where-Object { $username.SID -in ($_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name"
            $groupString = $groups -join ';'
            $accounts["$username"] = "$groupString"
        }

        $choice = Get-Option -Options $accounts -ReturnValue -LineAfter
        $data = Get-UserData $choice
        Write-Text -Type "list" -List $data

        return $choice
    } catch {
        Write-Text -Type "error" -Text "Select user error: $($_.Exception.Message)"
    }
}