
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}
    

function Install-Bginfo {
    try {
        Write-Welcome -Title "Install BGInfo" -Description "Install BGInfo with various DSO flavor profiles." -Command "intall bginfo"

        $options = (
            "Default",
            "Nuvia ISR"
        )

        $choice = Get-Option -Options $options -LineBefore -LineAfter

        if ($choice -eq 0) { 
            $url = "https://drive.google.com/uc?export=download&id=1wBYV4MFbC68YhIUFcFeul8iuMsy1Qo_N" 
            $target = "Default" 
        }
        if ($choice -eq 1) { 
            $url = "https://drive.google.com/uc?export=download&id=18gFWHawWknKufHXjcmMUB0SwGoSlbBEk" 
            $target = "NuviaISR" 
        }

        $download = Get-Download -Url $url -Target "C:\Windows\Temp\$target`_BGInfo.zip"

        if (!$download) { Write-Exit -Script "Intech-InstallBginfo" }

        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallPaper -Value ""
        Set-ItemProperty -Path "HKCU:Control Panel\Colors" -Name Background -Value "0 0 0"

        Expand-Archive -LiteralPath "C:\Windows\Temp\$target`_BGInfo.zip" -DestinationPath "C:\Windows\Temp\"

        Remove-Item -Path "C:\Windows\Temp\$target`_BGInfo.zip" -Recurse

        ROBOCOPY "C:\Windows\Temp\BGInfo" "C:\Program Files\BGInfo" /E /NFL /NDL /NJH /NJS /nc /ns | Out-Null
        ROBOCOPY "C:\Windows\Temp\BGInfo" "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" "Start BGInfo.bat" /NFL /NDL /NJH /NJS /nc /ns | Out-Null

        Start-Process -FilePath "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\Start BGInfo.bat" -WindowStyle Hidden

        Remove-Item -Path "C:\Windows\Temp\BGInfo" -Recurse 

        Write-Host
        Write-Exit -Message "BGInfo installed and applied." -Script "Intech-InstallBginfo" -LineBefore
    } catch {
        Write-Text -Type "error" -Text "Install BGInfo error: $($_.Exception.Message)"
        Write-Exit -Script "Intech-InstallBginfo"
    }
}