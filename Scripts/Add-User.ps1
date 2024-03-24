if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

function Add-User {
    $scriptDescription = @"
 This is the Chaste Scripts menu. Here you can select the various functions without
 typing out commands.
"@

    Write-Welcome -Title "Add User v0323241029" -Description "$scriptDescription"

    Write-Text -Type "header" -Text "Local or domain user?" -LineAfter -LineBefore
    $choice = Get-Option -Options $([ordered]@{
            "Add local user"  = "Toggle the Windows built in administrator account."
            "Add domain user" = "Add a user to the system."
        }) -LineAfter

    if ($choice -eq 0) { $fileFunc = "Add-LocalUser" }
    if ($choice -eq 1) { $fileFunc = "Add-AdUser" }

    New-Item -Path "$env:TEMP\Chaste-Script.ps1" -ItemType File -Force | Out-Null

    $url = "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main"
    $dependencies = @("$fileFunc", "Global", "Get-Input", "Get-Option", "Get-UserData", "Get-Download", "Select-User")
    $subPath = "Framework"

    foreach ($dependency in $dependencies) {
        if ($dependency -eq $fileFunc) { $subPath = "Scripts" } else { $subPath = "Framework" }
        if ($dependency -eq 'Reclaim') { $subPath = "Plugins" }
        Get-Download -Url "$url/$subPath/$dependency.ps1" -Target "$env:TEMP\$dependency.ps1" | Out-Null
        $rawScript = Get-Content -Path "$env:TEMP\$dependency.ps1" -Raw -ErrorAction SilentlyContinue
        Add-Content -Path "$env:TEMP\Chaste-Script.ps1" -Value $rawScript
        Get-Item -ErrorAction SilentlyContinue "$env:TEMP\$dependency.ps1" | Remove-Item -ErrorAction SilentlyContinue
        if ($subPath -eq 'Plugins') { break }
    }

    if ($subPath -ne 'Plugins') {
        Add-Content -Path "$env:TEMP\Chaste-Script.ps1" -Value "Invoke-Script '$fileFunc'"
    }

    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$env:TEMP\Chaste-Script.ps1`"" -WorkingDirectory $pwd -Verb RunAs
}

