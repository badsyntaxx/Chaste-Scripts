if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
} 

$Script = "Edit-UserName"
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
   This script allows you to modify the username of a user on a Windows system. 
"@

$core = @"
function Edit-UserName {
    try {
        Write-Host "`n   Chaste Scripts: Edit User Name v0315240404"
        Write-Host "$des" -ForegroundColor DarkGray

        `$username = Select-User

        Write-Text -Type "header" -Text "Enter username" -LineBefore

        `$newName = Get-Input -Prompt "" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser

        `$data = Get-AccountInfo -Username `$username

        Write-Text -Type "notice" -Text "## You're about to change this users name." -LineBefore -LineAfter
        Write-Box -Text `$data

        `$options = @(
            "Submit  - Confirm and apply." 
            "Reset   - Start over at the beginning."
            "Exit    - Run a different command."
        )

        `$choice = Get-Option -Options `$options -LineBefore
        if (`$choice -ne 0 -and `$choice -ne 1 -and `$choice -ne 2) { Edit-UserName }
        if (`$choice -eq 1) { Invoke-Script "Edit-UserName" }
        if (`$choice -eq 2) { Write-Exit -Script "Edit-UserName" }

        Write-Text -Type "notice" -Text "Applying name change..." -LineBefore
    
        Rename-LocalUser -Name `$username -NewName `$newName

        Write-Text -Type "notice" -Text "Name change applied." -LineAfter

        Write-Exit "The name for this account has been changed." -Script "Edit-UserName"
    } catch {
        Write-Text -Type "error" -Text "Edit name error: `$(`$_.Exception.Message)"
        Write-Exit -Script "Edit-UserName"
    }
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -File "$path\$Script.ps1" -Verb RunAs