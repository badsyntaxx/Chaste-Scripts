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
        Get-Item -ErrorAction SilentlyContinue "$path\$script.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host "`n Chaste Scripts: Install BGInfo v0317241028"
        Write-Host "$des`n" -ForegroundColor DarkGray

        `$text = @(
            "What this script does."
            " "
            "1. Downloads a BGInfo.zip containing BGInfo install."
            "2. Opens the archive and copies the BGInfo folder to 'Program Files'."
            "3. Adds a 'Start BGInfo.bat' to the common startup folder."
            "4. Runs the .bat file and apply the background."
            " "
        )

        Write-Box -Text `$text

        `$options = (
            "Default",
            "Nuvia ISR"
        )

        `$choice = Get-Option -Options `$options -LineBefore -LineAfter

        if (`$choice -eq 0) { 
            `$url = "https://drive.google.com/uc?export=download&id=1wBYV4MFbC68YhIUFcFeul8iuMsy1Qo_N" 
            `$target = "Default" 
        }
        if (`$choice -eq 1) { 
            `$url = "https://drive.google.com/uc?export=download&id=18gFWHawWknKufHXjcmMUB0SwGoSlbBEk" 
            `$target = "NuviaISR" 
        }

        `$download = Get-Download -Url `$url -Target "C:\Windows\Temp\`$target_BGInfo.zip"

        if (!`$download) { Write-Exit -Script "Install-BGInfo" }

        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallPaper -Value ""
        Set-ItemProperty -Path "HKCU:Control Panel\Colors" -Name Background -Value "0 0 0"

        Expand-Archive -LiteralPath "C:\Windows\Temp\`$target_BGInfo.zip" -DestinationPath "C:\Windows\Temp\"

        Remove-Item -Path "C:\Windows\Temp\`$target_BGInfo.zip" -Recurse

        ROBOCOPY "C:\Windows\Temp\BGInfo" "C:\Program Files\BGInfo" /E /NFL /NDL /NJH /NJS /nc /ns | Out-Null
        ROBOCOPY "C:\Windows\Temp\BGInfo" "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" "Start BGInfo.bat" /NFL /NDL /NJH /NJS /nc /ns | Out-Null

        Start-Process -FilePath "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\Start BGInfo.bat" -WindowStyle Hidden

        Remove-Item -Path "C:\Windows\Temp\BGInfo" -Recurse 

        Write-Host
        Write-Exit -Message "BGInfo installed and applied." -Script "Install-BGInfo" -LineBefore
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