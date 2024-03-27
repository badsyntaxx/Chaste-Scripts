function Install-Tscan {
    try {
        Write-Welcome -Title "Install T-Scan" -Description "Install T-Scan for Nuvia" -Command "intech install isr ninja"
        Write-Text -Type "header" -Text "Installing T-Scan for Nuvia" -LineBefore -LineAfter

        Add-TscanFolder

        Set-Service -Name "SSDPSRV" -StartupType Automatic
        Start-Service -Name "SSDP Discovery"
        Set-Service -Name "upnphost" -StartupType Automatic
        Start-Service -Name "UPnP Device Host"
        Set-NetFirewallRule -DisplayGroup "Network Discovery" -Enabled True
        Set-NetFirewallRule -DisplayGroup "File and Printer Sharing" -Enabled True

        robocopy "\\NUVFULSVR\InTech\59179_T-Scan_v10_KALLIE_NUVIA_DENTAL_IMPLANT_CENTER" "$env:TEMP\tscan" /E /IS /COPYALL
          
        Start-Process -FilePath "$env:TEMP\tscan\tekscan\setup.exe" -ArgumentList "/quiet" -Wait
        Get-Item -ErrorAction SilentlyContinue "$env:TEMP\tscan" | Remove-Item -ErrorAction SilentlyContinue -Confirm $false
        Write-Exit -Script "Install-Tscan"
    } catch {
        Write-Text -Type "error" -Text "Install error: $($_.Exception.Message)"
        Write-Exit -Script "Install-Tscan"
    }
}

function Add-TscanFolder {
    try {
        Write-Text "Creating TScan folder..."
        Write-Text "$env:TEMP\tscan"

        if (-not (Test-Path -PathType Container "$env:TEMP\tscan")) {
            New-Item -Path "$env:TEMP" -Name "tscan" -ItemType Directory | Out-Null
        }
        
        Write-Text -Type "done" -Text "Folder created." -LineAfter
    } catch {
        Write-Text "Error creating temp folder: $($_.Exception.Message)" -Type "error"
    }
}

