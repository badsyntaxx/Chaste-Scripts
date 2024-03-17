if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
} 

$Script = "Set-ComputerName"
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
 This function enables you to modify the hostname and description 
 of a Windows computer without requiring a system reboot.
"@

$core = @"
function Set-ComputerName {
    try {
        Write-Host "`n Chaste Scripts: Edit Hostname v0315240737"
        Write-Host "$des" -ForegroundColor DarkGray

        `$currentHostname = `$env:COMPUTERNAME
        `$currentDescription = (Get-WmiObject -Class Win32_OperatingSystem).Description

        Write-Text -Type "header" -Text "Enter hostname" -LineBefore -LineAfter

        `$hostname = Get-Input -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,15})$" -Value `$currentHostname

        Write-Text -Type "header" -Text "Enter description" -LineBefore -LineAfter

        `$description = Get-Input -Validate "^(\s*|[a-zA-Z0-9 |_\-]{1,64})$" -Value `$currentDescription

        if (`$hostname -eq "") { `$hostname = `$currentHostname } 
        if (`$description -eq "") { `$description = `$currentDescription } 

        Write-Text -Type "notice" -Text "You're about to change the computer name and description." -LineBefore -LineAfter

        `$options = @(
            "Submit  - Confirm and apply." 
            "Reset   - Start over at the beginning."
            "Exit    - Run a different command."
        )

        `$choice = Get-Option -Options `$options

        if (`$choice -ne 0 -and `$choice -ne 2) { Invoke-Script "Set-ComputerName" }
        if (`$choice -eq 2) { Write-Exit -Script "Set-ComputerName" }

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
        Write-Exit -Message "The PC name changes have been applied. No restart required!" -Script "Set-ComputerName"
    } catch {
        Write-Text -Type "error" -Text "Rename computer error: `$(`$_.Exception.Message)"
        Write-Exit -Script "Set-ComputerName"
    }
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -File "$path\$Script.ps1" -Verb RunAs