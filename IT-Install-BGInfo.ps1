if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
} 

$script = "Install-BGInfo"
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
$path = if ($isAdmin) { "$env:SystemRoot\Temp" } else { "$env:TEMP" }

if (Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -ErrorAction SilentlyContinue) {
    $framework = Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -Raw
    Write-Host "   Using local file."
    Start-Sleep 1
} else {
    $framework = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1"
}

$des = @"
 This function allows you to install BGInfo. Just paste a link to your BGInfo.zip.
"@

$core = @"
function Install-BGInfo {
    try {
        Write-Host "`n Chaste Scripts: Install BGInfo v0317241028"
        Write-Host "$des`n" -ForegroundColor DarkGray

        `$boxText = "This link is the BGInfo folder I install for Nuvia ISR's"
        `$boxLink = "https://drive.google.com/uc?export=download&id=1vU-AfOmhwdwh7h_Q0IFGXClGQ4AQjjSK"
        `$text = @(
            "What this script does."
            " "
            "1.Once a link to a BGInfo.zip is provided, it will download the archive."
            "2.Open the archive and copy the BGInfo folder to 'Program Files'."
            "3.Add a 'Start BGInfo.bat' to the common startup folder."
            "4.Run the .bat file and apply the background."
            " "
            "Example BGInfo.zip:"
            "https://drive.google.com/uc?export=download&id=1vU-AfOmhwdwh7h_Q0IFGXClGQ4AQjjSK"
            " "
            "My example BGInfo.zip is the one I use for Nuvia ISR's. It contains some"
            "VB scripts to compact some network information, because BGInfos default"
            "view shows too much empty data for my taste."
        )

        Write-Box -Text `$text

        `$url = Get-Input -Prompt "" -LineBefore -LineAfter

        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallPaper -Value ""
        Set-ItemProperty -Path "HKCU:Control Panel\Colors" -Name Background -Value "0 0 0"

        `$download = Get-Download -Url `$url -Target "C:\Windows\Temp\BGInfo.zip"
    
        if (!`$download) { Write-Exit -Script "Install-BGInfo" }

        Expand-Archive -LiteralPath "C:\Windows\Temp\BGInfo.zip" -DestinationPath "C:\Windows\Temp\"

        Remove-Item -Path "C:\Windows\Temp\BGInfo.zip" -Recurse

        ROBOCOPY "C:\Windows\Temp\BGInfo" "C:\Program Files\BGInfo" /E /NFL /NDL /NJH /NJS /nc /ns | Out-Null
        ROBOCOPY "C:\Windows\Temp\BGInfo" "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" "Start BGInfo.bat" /NFL /NDL /NJH /NJS /nc /ns | Out-Null

        Start-Process -FilePath "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\Start BGInfo.bat" -WindowStyle Hidden

        Remove-Item -Path "C:\Windows\Temp\BGInfo" -Recurse 

        Write-Host
        Write-Exit -Message "BGInfo installed and applied." -Script "Set-DesktopConfig" -LineBefore
    } catch {
        Write-Text -Type "error" -Text "Install BGInfo error: `$(`$_.Exception.Message)"
        Write-Exit -Script "Install-BGInfo"
    }
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -NoExit -File "$path\$Script.ps1" -Verb RunAs