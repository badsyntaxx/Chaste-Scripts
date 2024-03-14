if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
    Exit;
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

$core = @"
function Edit-UserName {
    try {
        `$username = Select-User

        Write-Text -Type "header" -Text "Change username" -LineBefore

        `$newName = Get-Input -Prompt "Username" -Validate "^(\s*|[a-zA-Z0-9 _\-]{1,64})$" -CheckExistingUser

        Write-Text -Type "header" -Text "Confirm name change" -LineBefore

        `$data = Get-AccountInfo -Username `$username

        Write-Text -Type "notice" -Text "NOTICE: You're about to change this users name."
        Write-Text -Type "recap" -Data `$data -LineAfter

        `$confirmation = @(
            "Submit  - Confirm and apply changes", 
            "Restart   - Start edit user over.", 
            "Exit    - Quit this script with an opportunity to run another."
        )

        `$choice = Get-Option -Options `$confirmation
        if (`$choice -ne 0 -and `$choice -ne 1 -and `$choice -ne 2) { Edit-UserName }
        if (`$choice -eq 1) { Invoke-Script "Edit-UserName" }
        if (`$choice -eq 2) { Write-CloseOut -Script "Edit-UserName" }
    
        Rename-LocalUser -Name `$username -NewName `$newName

        Write-CloseOut "The name for this account has been changed." -Script "Edit-UserName"
    } catch {
        Write-Text -Type "error" -Text "Set Name Error: `$(`$_.Exception.Message)"
    }
}

function Get-AccountInfo {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$username
    )

    try {
        `$user = Get-LocalUser -Name `$Username
        `$groups = Get-LocalGroup | Where-Object { `$user.SID -in (`$_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name"
        `$userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '`$(`$user.SID)'"
        `$dir = `$userProfile.LocalPath
        if (`$null -ne `$userProfile) { `$dir = `$userProfile.LocalPath } else { `$dir = "Awaiting first sign in." }

        `$source = Get-LocalUser -Name `$Username | Select-Object -ExpandProperty PrincipalSource

        `$data = [ordered]@{
            "Name"   = `$Username
            "Groups" = "`$(`$groups -join ';')"
            "Path"   = `$dir
            "Source" = `$source
        }

        return `$data
    } catch {
        Write-Alert -Type "error" -Text "ERROR: `$(`$_.Exception.Message)"
        Read-Host -Prompt "Press any key to continue"
    }
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -File "$path\$Script.ps1" -Verb RunAs