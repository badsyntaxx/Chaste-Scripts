if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

$script = "Add-DomainUser"
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
 This function creates a new domain user account on a Windows system with specified settings, 
 including the username, optional password, and group. The account and password never expire.
"@

$core = @"
function $script {
    try {
        Get-Item -ErrorAction SilentlyContinue "$path\$script.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host " Chaste Scripts: Add Domain User v0321240710"
        Write-Host "$des" -ForegroundColor DarkGray

        Write-Text -Type "header" -Text "Enter name" -LineBefore -LineAfter
        `$name = Get-Input -Prompt "" -Validate "^([a-zA-Z0-9 _\-]{1,64})$"  -CheckExistingUser

        Write-Text -Type "header" -Text "Enter sam name" -LineBefore -LineAfter
        `$saNname = Get-Input -Prompt "" -Validate "^([a-zA-Z0-9 _\-]{1,20})$"  -CheckExistingUser

        Write-Text -Type "header" -Text "Enter password" -LineBefore -LineAfter
        `$password = Get-Input -Prompt "" -IsSecure
        
        Write-Text -Type "header" -Text "Set group membership" -LineBefore -LineAfter
        `$choice = Get-Option -Options @("Administrator", "Standard user")
        
        if (`$choice -eq 0) { `$group = 'Administrators' } else { `$group = "Users" }
        if (`$group -eq 'Administrators') { `$groupDisplay = 'Administrator' } else { `$groupDisplay = 'Standard user' }

        Write-Text -Type "notice" -Text "You're about to create a new local user!" -LineBefore -LineAfter

        `$choice = Get-Option -Options @(
            "Submit  - Confirm and apply." 
            "Reset   - Start over at the beginning."
            "Exit    - Run a different command."
        ) -LineAfter

        if (`$choice -ne 0 -and `$choice -ne 2) { Invoke-Script "$script" }
        if (`$choice -eq 2) {  Write-Exit -Script "$script" }

        New-ADUser -Name `$name 
        -SamAccountName `$SamAccountName 
        -GivenName `$GivenName 
        -Surname `$Surname 
        -UserPrincipalName `"`UserPrincipalName@`$domainName.com`" 
        -AccountPassword `$password 
        -Enabled `$true

        Add-LocalGroupMember -Group `$group -Member `$name -ErrorAction Stop

        `$data = Get-UserData `$name

        Write-Text -Type "list" -List `$data -LineAfter

        Write-Exit -Message "The user account was created." -Script "$script" 
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