function Install-IsrNinja {
    try {
        Write-Welcome -Title "Install NinjaOne" -Description "Install NinjaOne for Nuvia ISR's" -Command "intech install isr ninja"
        Write-Text -Type "header" -Text "Installing NinjaOne for Nuvia ISR Center" -LineBefore -LineAfter

        $url = "https://app.ninjarmm.com/agent/installer/0274c0c3-3ec8-44fc-93cb-79e96f191e07/nuviaisrcenteroremut-5.7.8836-windows-installer.msi"
        $service = Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue

        if ($null -ne $service -and $service.Status -eq "Running") {
            Write-Text -Type "done" -Text "NinjaRMMAgent is already installed and running."
        } else {
            $download = Get-Download -Url $Url -Target "$env:TEMP\NinjaOne.msi"
            if (!$download) { throw "Unable to acquire intaller." }
          
            Start-Process -FilePath "msiexec" -ArgumentList "/i `"$env:TEMP\NinjaOne.msi`" /qn" -Wait

            $service = Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue
            if ($null -ne $service -and $service.Status -eq "Running") {
                Write-Text -Type "success" -Text "NinjaOne successfully installed." -LineAfter
            } else {
                Write-Text -Type "error" -Text "NinjaOne did not successfully install." -LineAfter
            } 
        }
        Get-Item -ErrorAction SilentlyContinue "$env:TEMP\NinjaOne.msi" | Remove-Item -ErrorAction SilentlyContinue
        Write-Exit -Script "Install-IsrNinja"
    } catch {
        Write-Text -Type "error" -Text "Install error: $($_.Exception.Message)"
        Write-Exit -Script "Install-IsrNinja"
    }
}

