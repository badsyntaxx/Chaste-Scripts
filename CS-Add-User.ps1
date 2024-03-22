if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

$script = "Add-User"
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
 Create new local and / or domain users.
"@

$core = @"
function $script {
    try {
        Get-Item -ErrorAction SilentlyContinue "$path\$script.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host "`n Chaste Scripts: Add User v0315241122"
        Write-Host "$des" -ForegroundColor DarkGray

        Write-Text -Type "header" -Text "What type of user do you want to add?" -LineBefore -LineAfter

        `$choice = Get-Option -Options @(
            'Local  - Create a local user.', 
            'Domain - Create a domain user.'
        )

        if (`$choice -eq 0) { 
            irm chaste.dev/add/user/local | iex
        }
        if (`$choice -eq 1) { 
            irm chaste.dev/add/user/domain | iex
        }
    } catch {
        Write-Text -Type "error" -Text "Add user error: `$(`$_.Exception.Message)"
        Write-Exit
    }
}

"@

New-Item -Path "$path\$script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$script.ps1" -Value $core
Add-Content -Path "$path\$script.ps1" -Value $framework
Add-Content -Path "$path\$script.ps1" -Value "Invoke-Script '$script'"

PowerShell.exe -NoExit -File "$path\$script.ps1" -Verb RunAs