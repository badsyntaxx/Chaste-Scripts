if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
    Exit;
} 

$script = "Add-InTechAdmin"
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
$path = if ($isAdmin) { "$env:SystemRoot\Temp" } else { "$env:TEMP" }
$framework = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1"

if (Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -ErrorAction SilentlyContinue) {
    Write-Host "   Using local file..."
    Start-Sleep 1
    $framework = Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -Raw
}

$FilePaths = @("$env:TEMP\$Script.ps1", "$env:SystemRoot\Temp\IT-$Script.ps1")
foreach ($FilePath in $FilePaths) { Get-Item $FilePath | Remove-Item }

$addInTechAdmin = @"
function Add-InTechAdmin {
    try {
        `$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
        `$path = if (`$isAdmin) { "`$env:SystemRoot\Temp\" } else { "`$env:TEMP\" }
        `$keyUrl = "https://drive.google.com/uc?export=download&id=1EGASU9cvnl5E055krXXcXUcgbr4ED4ry"
        `$phraseUrl = "https://drive.google.com/uc?export=download&id=1jbppZfGusqAUM2aU7V4IeK0uHG2OYgoY"
        `$accountName = "InTechAdmin"

        Write-Host "Chaste Scripts" -ForegroundColor DarkGray
        Write-Text -Type "heading" -Text "Creating InTechAdmin account" 
        Write-Text "Getting credentials" -Type "header"
        `$keyDownload = Get-Download -Url `$keyUrl -Output "`$path\KEY.txt"
        `$pwDownload = Get-Download -Url `$phraseUrl -Output "`$path\PHRASE.txt"
        if (`$keyDownload -and `$pwDownload) { Write-Text "Credentials acquired." -Type "done" } else { throw "Unable to acquire credentials." }

        `$password = Get-Content -Path "`$path\PHRASE.txt" | ConvertTo-SecureString -Key (Get-Content -Path "`$path\KEY.txt")
        Write-Text "Credentials decrypted." -Type "done"

        Write-Text "Creating account" -Type "header"
        `$account = Get-LocalUser -Name `$accountName -ErrorAction SilentlyContinue
        if (`$null -eq `$account) {
            New-LocalUser -Name `$accountName -Password `$password -FullName "" -Description "InTech Administrator" -AccountNeverExpires -PasswordNeverExpires -ErrorAction stop
            Write-Text "Account created." -Type "done"
            Add-LocalGroupMember -Group "Administrators" -Member `$accountName -ErrorAction stop
            Write-Text "Group assignment successful." -Type "done"
            Write-Text "The InTechAdmin account has been created." -Type "Success" -LineAfter
        } else {
            Write-Text "NOTICE: InTechAdmin account already exists!" -Type "notice"
            Write-Text "Updating password..."
            `$account = Get-LocalUser -Name `$accountName
            `$account | Set-LocalUser -Password `$password
            Write-Text "Credentials applied." -Type "done"
            Write-Text "InTechAdmin password updated." -Type "Success" -LineAfter
        }

        Remove-Item -Path "`$path\PHRASE.txt"
        Remove-Item -Path "`$path\KEY.txt"
        Write-CloseOut -Script "Add-IntechAdmin"
    } catch {
        Write-Text "`$(`$_.Exception.Message)" -Type "error"
        Read-Host "   Press any key to continue"
    }
}

"@

New-Item -Path "$path\$script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$script.ps1" -Value $addInTechAdmin
Add-Content -Path "$path\$script.ps1" -Value $framework
Add-Content -Path "$path\$script.ps1" -Value "Initialize-Script '$script'"

PowerShell.exe -File "$path\$script.ps1" -Verb RunAs