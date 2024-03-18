if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
} 

$script = "Remove-User"
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
   This function allows you to remove a user from a Windows system, with options 
   to delete or keep their user profile / data.
"@

$core = @"
function Remove-User {
    try {
        Write-Host "`n   Chaste Scripts: Remove User v0315241122"
        Write-Host "$des" -ForegroundColor DarkGray

        `$username = Select-User

        Write-Text -Type "header" -Text "Delete user data" -LineBefore -LineAfter
        
        `$options = @(
            "Delete  - Also delete the users data.",
            "Keep    - Do not delete the users data."
            "Back    - Go back to action selection."
        )

        `$choice = Get-Option -Options `$options -LineAfter
        if (`$choice -eq 0) { `$deleteData = `$true }
        if (`$choice -eq 1) { `$deleteData = `$false }
        if (`$choice -eq 2) { Select-Action -Username `$username }

        if (`$deleteData) {
            Write-Text -Type "notice" "You're about to delete this account and it's data!" -LineBefore -LineAfter
        } else {
            Write-Text -Type "notice" "You're about to delete this account!" -LineBefore -LineAfter
        }

        `$options = @(
            "Submit  - Confirm and apply." 
            "Reset   - Start over at the beginning."
            "Exit    - Run a different command."
        )
        
        `$choice = Get-Option -Options `$options

        if (`$choice -ne 0 -and `$choice -ne 2) { Invoke-Script "$script" }
        if (`$choice -eq 2) { Write-Exit -Script "$script" }

        Remove-LocalUser -Name `$username

        Write-Text -Text "Local user removed." -Color "Yellow" -LineBefore
        
        if (`$deleteData) {
            `$userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '`$(`$user.SID)'"
            `$dir = `$userProfile.LocalPath
            if (`$null -ne `$dir -And (Test-Path -Path `$dir)) { 
                Remove-Item -Path `$dir -Recurse -Force 
                Write-Text -Text "User data deleted." -Color "Yellow"
            } else {
                Write-Text -Text "No data found." -Color "Yellow"
            }
        }

        Write-Text -Type "success" -Text "The user has been deleted." -LineBefore -LineAfter

        `$resetOptions = @(
            "Remove another user  - Start over and remove another user." 
            "Exit                 - Quit this script with an opportunity to run another."
        )
        
        `$choice = Get-Option -Options `$resetOptions

        if (`$choice -eq 0) { Invoke-Script "$script" }
        if (`$choice -eq 1) { Write-Exit -Script "$script" }
    } catch {
        Write-Text -Type "error" -Text "Remove User Error: `$(`$_.Exception.Message)"
        Write-Exit
    }
}

"@

New-Item -Path "$path\$script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$script.ps1" -Value $core
Add-Content -Path "$path\$script.ps1" -Value $framework
Add-Content -Path "$path\$script.ps1" -Value "Invoke-Script '$script'"

PowerShell.exe -File "$path\$script.ps1" -Verb RunAs