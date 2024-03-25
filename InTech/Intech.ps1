function Intech {
    try {
        Write-Welcome -Title "Chaste Scripts Menu" -Description "Select an action to take." -Command "menu"

        Write-Text -Type "header" -Text "Selection" -LineAfter -LineBefore
        $choice = Get-Option -Options $([ordered]@{
                "Add InTech Admin" = "Add the InTech administrator account to this PC."
                "Install BGInfo"   = "Install BGInfo with a chosen DSO flavor profile."
            }) -LineAfter

        if ($choice -eq 0) { $fileFunc = "Intech-AddAdmin" }
        if ($choice -eq 1) { $fileFunc = "Intech-InstallBginfo" }

        New-Item -Path "$env:TEMP\Chaste-Script.ps1" -ItemType File -Force | Out-Null

        $url = "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main"
        $dependencies = @("$fileFunc", "Global", "Get-Input", "Get-Option", "Get-UserData", "Get-Download", "Select-User")

        foreach ($dependency in $dependencies) {
            Get-Download -Url "$url/InTech/$dependency.ps1" -Target "$env:TEMP\$dependency.ps1" -ProgressText "Loading" | Out-Null
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

