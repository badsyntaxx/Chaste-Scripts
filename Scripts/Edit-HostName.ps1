if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

function Invoke-This {
    $scriptName = "Edit-Hostname"

    $scriptDescription = @"
 This function enables you to modify the hostname and description 
 of a Windows computer without requiring a system reboot.
"@

    $core = @"
function $scriptName {
    try {
        Write-Welcome -File $scriptName.ps1 -Title "Edit Hostname v0315241122" -Description `"$scriptDescription`"

        `$currentHostname = `$env:COMPUTERNAME
        `$currentDescription = (Get-WmiObject -Class Win32_OperatingSystem).Description

        Write-Text -Type "header" -Text "Enter hostname" -LineBefore -LineAfter
        `$hostname = Get-Input -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,15})$" -Value `$currentHostname

        Write-Text -Type "header" -Text "Enter description" -LineBefore -LineAfter
        `$description = Get-Input -Validate "^(\s*|[a-zA-Z0-9 |_\-]{1,64})$" -Value `$currentDescription

        if (`$hostname -eq "") { `$hostname = `$currentHostname } 
        if (`$description -eq "") { `$description = `$currentDescription } 

        Write-Text -Type "notice" -Text "You're about to change the computer name and description." -LineBefore -LineAfter
        `$choice = Get-Option -Options `$([ordered]@{
            "Submit"  = "Confirm and apply." 
            "Reset"   = "Start over at the beginning."
            "Exit"    = "Run a different command."
        })

        if (`$choice -ne 0 -and `$choice -ne 2) { Invoke-Script "$scriptName" }
        if (`$choice -eq 2) { Write-Exit -Script "$scriptName" }

        if (`$hostname -ne "") {
            Remove-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "Hostname" 
            Remove-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "NV Hostname" 
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Computername\Computername" -name "Computername" -value `$hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Computername\ActiveComputername" -name "Computername" -value `$hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "Hostname" -value `$hostname
            Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "NV Hostname" -value  `$hostname
            Set-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -name "AltDefaultDomainName" -value `$hostname
            Set-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -name "DefaultDomainName" -value `$hostname
        } 

        if (`$description -ne "") {
            Set-CimInstance -Query 'Select * From Win32_OperatingSystem' -Property @{Description = `$description }
        } 

        Write-Host
        Write-Exit -Message "The PC name changes have been applied. No restart required!" -Script "$scriptName"
    } catch {
        Write-Text -Type "error" -Text "Rename computer error: `$(`$_.Exception.Message)"
        Write-Exit -Script "$scriptName"
    }
}

"@

    New-Item -Path "$env:TEMP\$scriptName.ps1" -ItemType File -Force | Out-Null

    $dependencies = @(
        'Global'
        'Get-Input'
        'Get-Option'
        'Get-UserData'
    )

    foreach ($dependency in $dependencies) {
        Get-Script -Url "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/Framework/$dependency.ps1" -Target "$env:TEMP\$dependency.ps1" | Out-Null
        $rawScript = Get-Content -Path "$env:TEMP\$dependency.ps1" -Raw
        Add-Content -Path "$env:TEMP\$scriptName.ps1" -Value $rawScript
        Get-Item -ErrorAction SilentlyContinue "$env:TEMP\$dependency.ps1" | Remove-Item -ErrorAction SilentlyContinue
    }

    Add-Content -Path "$env:TEMP\$scriptName.ps1" -Value $core
    Add-Content -Path "$env:TEMP\$scriptName.ps1" -Value "Invoke-Script '$scriptName'"

    Start-Process powershell.exe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$env:TEMP\$scriptName.ps1`"" -WorkingDirectory $pwd -Verb RunAs
}

function Get-Script {
    param (
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$Target
    )

    try {
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $response = $request.GetResponse()

        if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
            throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$Url'."
        }

        [byte[]]$buffer = new-object byte[] 1048576
        [long]$total = [long]$count = 0

        $reader = $response.GetResponseStream()
        $writer = new-object System.IO.FileStream $Target, "Create"

        do {
            $count = $reader.Read($buffer, 0, $buffer.Length)
            $writer.Write($buffer, 0, $count)
            $total += $count
        } while ($count -gt 0)
        if ($count -eq 0) { return $true } else { return $false }
    } catch {
        Write-Host "Loading failed..."
        
        if ($retryCount -lt $MaxRetries) {
            Write-Host "Retrying..."
            Start-Sleep -Seconds $Interval
        } else {
            Write-Host "Maximum retries reached. Loading failed."
        }
    } finally {
        if ($reader) { $reader.Close() }
        if ($writer) { $writer.Flush(); $writer.Close() }
        [GC]::Collect()
    } 
}   

Invoke-This