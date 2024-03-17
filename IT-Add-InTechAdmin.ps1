if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
} 

$script = "Add-InTechAdmin"
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
   This function allows you to create an InTechAdmin account.
   The account password is encrypted and is never exposed.
"@

$addInTechAdmin = @"
function Add-InTechAdmin {
    try {
        Write-Host "`n   Chaste Scripts: Add InTechAdmin Account v0315241122"
        Write-Host "$des" -ForegroundColor DarkGray

        Write-Text -Type "header" -Text "Getting credentials" -LineBefore

        `$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
        `$path = if (`$isAdmin) { "`$env:SystemRoot\Temp" } else { "`$env:TEMP" }
        `$accountName = "InTechAdmin"

        `$downloads = [ordered]@{
            "`$path\KEY.txt" = "https://drive.google.com/uc?export=download&id=1EGASU9cvnl5E055krXXcXUcgbr4ED4ry"
            "`$path\PHRASE.txt" = "https://drive.google.com/uc?export=download&id=1jbppZfGusqAUM2aU7V4IeK0uHG2OYgoY"
        }

        foreach (`$d in `$downloads.Keys) {
            `$download = Get-Download -Url `$downloads[`$d] -Target `$d
        } 

        if (!`$download) { throw "Unable to acquire credentials." }

        `$password = Get-Content -Path "`$path\PHRASE.txt" | ConvertTo-SecureString -Key (Get-Content -Path "`$path\KEY.txt")
        Write-Text -Type "done" -Text "Credentials decrypted."

        Write-Text -Type "header" -Text "Creating account" -LineBefore
        `$account = Get-LocalUser -Name `$accountName -ErrorAction SilentlyContinue
        if (`$null -eq `$account) {
            New-LocalUser -Name `$accountName -Password `$password -FullName "" -Description "InTech Administrator" -AccountNeverExpires -PasswordNeverExpires -ErrorAction stop | Out-Null
            Write-Text -Type "done" -Text "Account created."
            Add-LocalGroupMember -Group "Administrators" -Member `$accountName -ErrorAction stop
            Write-Text -Type "done" -Text "Group assignment successful."
            Write-Text -Type "don" -Text "The InTechAdmin account has been created."
        } else {
            Write-Text -Type "notice" -Text "NOTICE: InTechAdmin account already exists!"
            Write-Text "Updating password..."
            `$account = Get-LocalUser -Name `$accountName
            `$account | Set-LocalUser -Password `$password
            Write-Text -Type "done" -Text "Password updated."
        }

        Remove-Item -Path "`$path\PHRASE.txt"
        Remove-Item -Path "`$path\KEY.txt"
        Write-Exit -Message "Task completed successfully." -Script "Add-IntechAdmin"
    } catch {
        Write-Text -Type "error" -Text "Create IntechAdmin Error: `$(`$_.Exception.Message)"
        Write-Exit -Script "$script"
    }
}

"@

New-Item -Path "$path\$script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$script.ps1" -Value $addInTechAdmin
Add-Content -Path "$path\$script.ps1" -Value $framework
Add-Content -Path "$path\$script.ps1" -Value "Invoke-Script '$script'"

PowerShell.exe -File "$path\$script.ps1" -Verb RunAs