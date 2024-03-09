if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
    Exit;
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

$core = @"
function Set-ComputerName {
    Write-Host "Chaste Scripts: Rename Computer" -ForegroundColor DarkGray
    Write-Text -Type "header" -Text "Name & Description" -LineBefore

    `$currentHostname = `$env:COMPUTERNAME
    `$currentDescription = (Get-WmiObject -Class Win32_OperatingSystem).Description

    `$hostname = Get-Input -Prompt "Hostname" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,15})$" -Value `$currentHostname
    `$description = Get-Input -Prompt "Description" -Validate "^(\s*|[a-zA-Z0-9 |_\-]{1,64})$" -Value `$currentDescription

    `$options = @(
        "Submit   - Confirm and apply changes", 
        "Reset    - Start rename computer over.", 
        "Exit     - Start over back at task selection."
    )

    if (`$hostname -eq "") { `$hostname = `$currentHostname } 
    if (`$description -eq "") { `$description = `$currentDescription } 

    `$data = [ordered]@{ "Hostname" = `$hostname }
    `$data = [ordered]@{ "Hostname" = `$hostname; "Description" = `$description }

    Write-Text "Confirm name settings" -Type "header" -LineBefore
    Write-Text -Type "notice" -Text "NOTICE: You're about to change the computer name and description."
    Write-Text -Type "recap" -Data `$data -LineAfter

    `$choice = Get-Option -Options `$options

    if (`$choice -ne 0 -and `$choice -ne 2) { Invoke-Script "Set-ComputerName" }
    if (`$choice -eq 2) { Write-CloseOut -Script "Set-ComputerName" }

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
    Write-CloseOut -Message "The PC name changes have been applied. No restart required!" -Script "Set-ComputerName"
}


"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -File "$path\$Script.ps1" -Verb RunAs