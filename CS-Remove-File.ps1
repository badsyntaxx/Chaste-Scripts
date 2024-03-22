if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

$script = "Remove-File"
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
 This function forcefully deletes a file.
"@

$core = @"
function Remove-File {
    try {
        Get-Item -ErrorAction SilentlyContinue "$path\$script.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host "`n Chaste Scripts: Remove File v0320241243"
        Write-Host "$des" -ForegroundColor DarkGray

        Write-Text -Type 'header' -Text 'Enter or paste the path and file' -LineBefore -LineAfter

        `$filepath = Get-Input -Prompt "" -LineAfter

        Get-Item `$filepath -ErrorAction SilentlyContinue | Remove-Item -Force 

        `$file = Get-Item `$filepath -ErrorAction SilentlyContinue

        if (!`$file) {
            Write-Exit -Message "File successfully deleted."
        }
    } catch {
        Write-Text -Type "error" -Text "Remove file error: `$(`$_.Exception.Message)"
        Write-Exit
    }
}

"@

New-Item -Path "$path\$script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$script.ps1" -Value $core
Add-Content -Path "$path\$script.ps1" -Value $framework
Add-Content -Path "$path\$script.ps1" -Value "Invoke-Script '$script'"

PowerShell.exe -NoExit -File "$path\$script.ps1" -Verb RunAs

