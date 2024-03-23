if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

$scriptName = "Invoke-ChasteScripts"
$scriptPath = $env:TEMP

$scriptDescription = @"
 This function creates a new local user account on a Windows system with specified settings, 
 including the username, optional password, and group. The account and password never expire.
"@

$core = @"
function $scriptName {
    try {
        Get-Item -ErrorAction SilentlyContinue "$scriptPath\$scriptName.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host " Chaste Scripts: v0319241206"
        Write-Host "$scriptDescription" -ForegroundColor DarkGray
        Get-Command
    } catch {
        Write-Text -Type "error" -Text "`$(`$_.Exception.Message)" -LineBefore -LineAfter
        Write-Exit -Script "$scriptName"
    }
}

"@

New-Item -Path "$scriptPath\$scriptName.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$scriptPath\$scriptName.ps1" -Value $core

Add-Content -Path "$scriptPath\$scriptName.ps1" -Value "Invoke-Script '$scriptName'"


Start-Process powershell.exe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$scriptPath\$scriptName.ps1`"" -WorkingDirectory $pwd -Verb RunAs