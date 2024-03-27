function Install-Tscan {
    try {
        Write-Welcome -Title "Install NinjaOne" -Description "Install NinjaOne for Nuvia ISR's" -Command "intech install isr ninja"
        Write-Text -Type "header" -Text "Installing NinjaOne for Nuvia ISR Center" -LineBefore -LineAfter

        Add-TscanFolder

        # Enable SSDP Discovery service
        Set-Service -Name "SSDPSRV" -StartupType Automatic
        Start-Service -Name "SSDP Discovery"

        # Enable UPnP Device Host service
        Set-Service -Name "upnphost" -StartupType Automatic
        Start-Service -Name "UPnP Device Host"

        # Enable Network Discovery rule
        Set-NetFirewallRule -DisplayGroup "Network Discovery" -Enabled True

        # Enable File and Printer Sharing rule
        Set-NetFirewallRule -DisplayGroup "File and Printer Sharing" -Enabled True

        robocopy "\\NUVFULSVR\InTech\59179_T-Scan_v10_KALLIE_NUVIA_DENTAL_IMPLANT_CENTER" "$env:TEMP\tscan" /E /IS /COPYALL
          
        Start-Process -FilePath "$env:TEMP\tscan\tekscan\setup.exe" -ArgumentList "/quiet" -Wait
        
        Get-Item -ErrorAction SilentlyContinue "$env:TEMP\tscan" | Remove-Item -ErrorAction SilentlyContinue
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

