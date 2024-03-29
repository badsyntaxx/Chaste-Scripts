function Edit-Hostname {
    try {
        Write-Welcome -Title "Edit Hostname" -Description "Edit the hostname and description of this computer." -Command "edit hostname"

        $currentHostname = $env:COMPUTERNAME
        $currentDescription = (Get-WmiObject -Class Win32_OperatingSystem).Description

        Write-Text -Type "header" -Text "Enter hostname" -LineBefore -LineAfter
        $hostname = Get-Input -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,15})$" -Value $currentHostname

        Write-Text -Type "header" -Text "Enter description" -LineBefore -LineAfter
        $description = Get-Input -Validate "^(\s*|[a-zA-Z0-9 |_\-]{1,64})$" -Value $currentDescription

        if ($hostname -eq "") { $hostname = $currentHostname } 
        if ($description -eq "") { $description = $currentDescription } 

        Write-Text -Type "notice" -Text "You're about to change the computer name and description." -LineBefore -LineAfter
        $choice = Get-Option -Options $([ordered]@{
                "Submit" = "Confirm and apply." 
                "Reset"  = "Start over at the beginning."
                "Exit"   = "Run a different command."
            })

        if ($choice -ne 0 -and $choice -ne 2) { Invoke-Script "Edit-Hostname" }
        if ($choice -eq 2) { Write-Exit -Script "Edit-Hostname" }

        if ($hostname -ne "") {
            Remove-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "Hostname" 
            Remove-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "NV Hostname" 
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Computername\Computername" -name "Computername" -value $hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Computername\ActiveComputername" -name "Computername" -value $hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "Hostname" -value $hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "NV Hostname" -value  $hostname
            Set-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -name "AltDefaultDomainName" -value $hostname
            Set-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -name "DefaultDomainName" -value $hostname
        } 

        if ($description -ne "") {
            Set-CimInstance -Query 'Select * From Win32_OperatingSystem' -Property @{Description = $description }
        } 

        Write-Host
        Write-Exit -Message "The PC name changes have been applied. No restart required!" -Script "Edit-Hostname"
    } catch {
        Write-Text -Type "error" -Text "Rename computer error: $($_.Exception.Message)"
        Write-Exit -Script "Edit-Hostname"
    }
}

