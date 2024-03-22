function Invoke-This {
    try {
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
            Exit
        }
    
        $scriptName = "Edit-Hostname"
        $scriptPath = $env:TEMP

        if (Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -ErrorAction SilentlyContinue) {
            $framework = Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -Raw
        } else {
            Get-Script -Url "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1" -Target "$scriptPath\CS-Framework.ps1"
            $framework = Get-Content -Path "$scriptPath\CS-Framework.ps1" -Raw
            Get-Item -ErrorAction SilentlyContinue "$scriptPath\CS-Framework.ps1" | Remove-Item -ErrorAction SilentlyContinue
        }

        $scriptDescription = @"
 This function enables you to modify the hostname and description 
 of a Windows computer without requiring a system reboot.
"@

        $core = @"
function $scriptName {
    try {
        Get-Item -ErrorAction SilentlyContinue "$scriptPath\$scriptName.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host "`n Chaste Scripts: Edit Hostname v0315240737"
        Write-Host "$scriptDescription" -ForegroundColor DarkGray

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

        New-Item -Path "$scriptPath\$scriptName.ps1" -ItemType File -Force | Out-Null

        Add-Content -Path "$scriptPath\$scriptName.ps1" -Value $core
        Add-Content -Path "$scriptPath\$scriptName.ps1" -Value $framework
        Add-Content -Path "$scriptPath\$scriptName.ps1" -Value "Invoke-Script '$scriptName'"

        Start-Process powershell.exe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$scriptPath\$scriptName.ps1`"" -WorkingDirectory $pwd -Verb RunAs
    } catch {
        Write-Host "$($_.Exception.Message)"
    }
}

function Get-Script {
    param (
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$Target
    )
        
    $request = [System.Net.HttpWebRequest]::Create($Url)
    $response = $request.GetResponse()
  
    if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
        throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$Url'."
    }
  
    if ($Target -match '^\.\\') {
        $Target = Join-Path (Get-Location -PSProvider "FileSystem") ($Target -Split '^\.')[1]
    }
            
    if ($Target -and !(Split-Path $Target)) {
        $Target = Join-Path (Get-Location -PSProvider "FileSystem") $Target
    }

    if ($Target) {
        $fileDirectory = $([System.IO.Path]::GetDirectoryName($Target))
        if (!(Test-Path($fileDirectory))) {
            [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null
        }
    }
  
    [byte[]]$buffer = new-object byte[] 1048576

    $reader = $response.GetResponseStream()
    $writer = new-object System.IO.FileStream $Target, "Create"

    do {
        $count = $reader.Read($buffer, 0, $buffer.Length)
        $writer.Write($buffer, 0, $count)
    } while ($count -gt 0)                
}  

Invoke-This