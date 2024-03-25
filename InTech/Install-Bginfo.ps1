function Install-Bginfo {
    try {
        Write-Welcome -Title "Install BGInfo" -Description "Install BGInfo with various DSO flavor profiles." -Command "intech intall bginfo"

        $choice = Get-Option -Options $([ordered]@{
                "Default" = "Generic install with no background and customizations by Chase."
                "Nuvia"   = "Customized BGInfo with Nuvia flavor profile."
            }) -LineBefore -LineAfter

        if ($choice -eq 0) { 
            $url = "https://drive.google.com/uc?export=download&id=1wBYV4MFbC68YhIUFcFeul8iuMsy1Qo_N" 
            $target = "Default" 
        }
        if ($choice -eq 1) { 
            $url = "https://drive.google.com/uc?export=download&id=18gFWHawWknKufHXjcmMUB0SwGoSlbBEk" 
            $target = "Nuvia" 
        }

        $download = Get-Download -Url $url -Target "$env:TEMP\$target`_BGInfo.zip"
        if (!$download) { Write-Exit -Script "Intech-InstallBginfo" }

        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallPaper -Value ""
        Set-ItemProperty -Path "HKCU:Control Panel\Colors" -Name Background -Value "0 0 0"

        Expand-Archive -LiteralPath "$env:TEMP\$target`_BGInfo.zip" -DestinationPath "$env:TEMP\"

        Remove-Item -Path "$env:TEMP\$target`_BGInfo.zip" -Recurse

        ROBOCOPY "$env:TEMP\BGInfo" "C:\Program Files\BGInfo" /E /NFL /NDL /NJH /NJS /nc /ns | Out-Null
        ROBOCOPY "$env:TEMP\BGInfo" "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" "Start BGInfo.bat" /NFL /NDL /NJH /NJS /nc /ns | Out-Null

        Start-Process -FilePath "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\Start BGInfo.bat" -WindowStyle Hidden

        Remove-Item -Path "$env:TEMP\BGInfo" -Recurse 

        Write-Host
        Write-Exit -Message "BGInfo installed and applied." -Script "Intech-InstallBginfo" -LineBefore
    } catch {
        Write-Text -Type "error" -Text "Install BGInfo error: $($_.Exception.Message)"
        Write-Exit -Script "Intech-InstallBginfo"
    }
}