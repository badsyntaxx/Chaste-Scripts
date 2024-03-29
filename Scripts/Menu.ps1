function Menu {
    try {
        Write-Welcome -Title "Chaste Scripts Menu" -Description "Select an action to take." -Command "menu"

        Write-Text -Type "header" -Text "Selection" -LineAfter -LineBefore
        $choice = Get-Option -Options $([ordered]@{
                "Enable administrator" = "Toggle the Windows built in administrator account."
                "Add user"             = "Add a user to the system."
                "Remove user"          = "Remove a user from the system."
                "Edit user name"       = "Edit a users name."
                "Edit user password"   = "Edit a users password."
                "Edit user group"      = "Edit a users group membership."
                "Edit hostname"        = "Edit this computers name and description."
                "Edit network adapter" = "Edit a network adapter.(beta)"
            }) -LineAfter

        if ($choice -eq 0) { $fileFunc = "Enable-Admin" }
        if ($choice -eq 1) { $fileFunc = "Add-User" }
        if ($choice -eq 2) { $fileFunc = "Remove-User" }
        if ($choice -eq 3) { $fileFunc = "Edit-UserName" }
        if ($choice -eq 4) { $fileFunc = "Edit-UserPassword" }
        if ($choice -eq 5) { $fileFunc = "Edit-UserGroup" }
        if ($choice -eq 6) { $fileFunc = "Edit-Hostname" }
        if ($choice -eq 7) { $fileFunc = "Edit-NetworkAdapter" }

        New-Item -Path "$env:TEMP\Chaste-Script.ps1" -ItemType File -Force | Out-Null

        $url = "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main"
        $dependencies = @("$fileFunc", "Global", "Get-Input", "Get-Option", "Get-UserData", "Get-Download", "Select-User")
        $subPath = "Framework"

        foreach ($dependency in $dependencies) {
            if ($dependency -eq $fileFunc) { $subPath = "Scripts" } else { $subPath = "Framework" }
            if ($dependency -eq 'Reclaim') { $subPath = "Plugins" }
            Get-Download -Url "$url/$subPath/$dependency.ps1" -Target "$env:TEMP\$dependency.ps1" -ProgressText "Loading" | Out-Null
            $rawScript = Get-Content -Path "$env:TEMP\$dependency.ps1" -Raw -ErrorAction SilentlyContinue
            Add-Content -Path "$env:TEMP\Chaste-Script.ps1" -Value $rawScript
            Get-Item -ErrorAction SilentlyContinue "$env:TEMP\$dependency.ps1" | Remove-Item -ErrorAction SilentlyContinue
            if ($subPath -eq 'Plugins') { break }
        }

        if ($subPath -ne 'Plugins') {
            Add-Content -Path "$env:TEMP\Chaste-Script.ps1" -Value "Invoke-Script '$fileFunc'"
        }

        $chasteScript = Get-Content -Path "$env:TEMP\Chaste-Script.ps1" -Raw
        Invoke-Expression "$chasteScript"
    } catch {
        Write-Text -Type "error" -Text "Menu error: $($_.Exception.Message)"
        Write-Exit -Script "Menu"
    }
}

