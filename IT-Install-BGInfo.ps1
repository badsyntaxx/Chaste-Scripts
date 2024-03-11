if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
    Exit;
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

$core = @"
function Install-BGInfo {
    try {
        Write-Host "Chaste Scripts: Install BGInfo" -ForegroundColor DarkGray
        Write-Text -Type "header" -Text "Install BGInfo" -LineBefore

        Write-Text -Text "Type or paste link to BGInfo zip."
        `$boxText = "This link is the BGInfo folder I install for Nuvia ISR's"
        `$boxLink = "https://drive.google.com/uc?export=download&id=1vU-AfOmhwdwh7h_Q0IFGXClGQ4AQjjSK"
        Write-Box -Text `$boxText -Link `$boxLink

        `$url = Get-Input -Prompt "Link"

        Write-Text "Removing current wallpaper."

        `$key = "HKCU:\Control Panel\Desktop"
        Set-ItemProperty -Path `$key -Name WallPaper -Value ""
        Set-ItemProperty -Path "HKCU:Control Panel\Colors" -Name Background -Value "0 0 0"

        Write-Text -Type "done" -Text "Current wallpaper removed."

        `$download = Get-Download -Uri `$url -Target "C:\Windows\Temp\BGInfo.zip"
    
        if (!`$download) {
            throw "Frick"
        }

        Expand-Archive -LiteralPath "C:\Windows\Temp\BGInfo.zip" -DestinationPath "C:\Windows\Temp\"

        Remove-Item -Path "C:\Windows\Temp\BGInfo.zip" -Recurse
        ROBOCOPY "C:\Windows\Temp\BGInfo" "C:\Program Files\BGInfo" /E /NFL /NDL /NJH /NJS /nc /ns | Out-Null
        ROBOCOPY "C:\Windows\Temp\BGInfo" "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" "Start BGInfo.bat" /NFL /NDL /NJH /NJS /nc /ns | Out-Null
        Start-Process -FilePath "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\Start BGInfo.bat" -WindowStyle Hidden
        Remove-Item -Path "C:\Windows\Temp\BGInfo" -Recurse 
        Write-CloseOut -Message "BGInfo installed and applied." -Script "Set-DesktopConfig"
    } catch {
        Write-Text -Type "error" -Text "Add User Error: `$(`$_.Exception.Message)"
        Read-Host "   Press any key to continue"
    }
    
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -NoExit -File "$path\$Script.ps1" -Verb RunAs