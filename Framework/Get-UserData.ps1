function Get-UserData {
    param (
        [parameter(Mandatory = $true)]
        [string]$Username
    )

    try {
        $user = Get-LocalUser -Name $Username
        $groups = Get-LocalGroup | Where-Object { $user.SID -in ($_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name"
        $userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '$($user.SID)'"
        $dir = $userProfile.LocalPath
        if ($null -ne $userProfile) { $dir = $userProfile.LocalPath } else { $dir = "Awaiting first sign in." }

        $source = Get-LocalUser -Name $Username | Select-Object -ExpandProperty PrincipalSource

        $data = @(
            "Name:$Username"
            "Groups:$($groups -join ';')"
            "Path:$dir"
            "Source:$source"
        )

        return $data
    } catch {
        Write-Alert -Type "error" -Text "Error getting account info: $($_.Exception.Message)"
        Write-Exit
    }
}


