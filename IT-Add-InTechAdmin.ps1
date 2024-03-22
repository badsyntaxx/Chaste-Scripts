function Invoke-This {
    try {
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
            Exit
        }
    
        $scriptName = "Add-InTechAdmin"
        $scriptPath = $env:TEMP

        if (Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -ErrorAction SilentlyContinue) {
            $framework = Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -Raw
        } else {
            Get-Script -Url "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1" -Target "$scriptPath\CS-Framework.ps1"
            $framework = Get-Content -Path "$scriptPath\CS-Framework.ps1" -Raw
            Get-Item -ErrorAction SilentlyContinue "$scriptPath\CS-Framework.ps1" | Remove-Item -ErrorAction SilentlyContinue
        }

        $scriptDescription = @"
 This function allows you to create an InTechAdmin account.
 The account password is encrypted and is never exposed.
"@

        $core = @"
function $scriptName {
    try {
        Get-Item -ErrorAction SilentlyContinue "$scriptPath\$scriptName.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host "`n Chaste Scripts: Add InTechAdmin Account v0315241122"
        Write-Host "$scriptDescription" -ForegroundColor DarkGray

        Write-Text -Type "header" -Text "Getting credentials" -LineBefore -LineAfter

        `$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
        `$path = if (`$isAdmin) { "`$env:SystemRoot\Temp" } else { "`$env:TEMP" }
        `$accountName = "InTechAdmin"

        `$downloads = [ordered]@{
            "`$path\KEY.txt" = "https://drive.google.com/uc?export=download&id=1EGASU9cvnl5E055krXXcXUcgbr4ED4ry"
            "`$path\PHRASE.txt" = "https://drive.google.com/uc?export=download&id=1jbppZfGusqAUM2aU7V4IeK0uHG2OYgoY"
        }

        foreach (`$d in `$downloads.Keys) { `$download = Get-Download -Url `$downloads[`$d] -Target `$d } 

        if (!`$download) { throw "Unable to acquire credentials." }

        `$password = Get-Content -Path "`$path\PHRASE.txt" | ConvertTo-SecureString -Key (Get-Content -Path "`$path\KEY.txt")

        Write-Text -Type "done" -Text "Credentials acquired."

        `$account = Get-LocalUser -Name `$accountName -ErrorAction SilentlyContinue

        if (`$null -eq `$account) {
            Write-Text -Type "header" -Text "Creating account" -LineBefore -LineAfter
            New-LocalUser -Name `$accountName -Password `$password -FullName "" -Description "InTech Administrator" -AccountNeverExpires -PasswordNeverExpires -ErrorAction stop | Out-Null
            Write-Text -Type "done" -Text "Account created."

            Add-LocalGroupMember -Group "Administrators" -Member `$accountName -ErrorAction stop
            Write-Text -Type "done" -Text "Group assignment successful." -LineAfter

            `$finalMessage = "Success! The InTechAdmin account has been created."
        } else {
            Write-Text -Type "notice" -Text "InTechAdmin account already exists!" -LineBefore -LineAfter
            Write-Text -Text "Updating password..." -LineAfter
            `$account | Set-LocalUser -Password `$password

            `$finalMessage = "Success! The InTechAdmin password was updated."
        }

        Remove-Item -Path "`$path\PHRASE.txt"
        Remove-Item -Path "`$path\KEY.txt"

        Write-Exit -Message `$finalMessage -Script "$scriptName"
    } catch {
        Write-Text -Type "error" -Text "Create IntechAdmin Error: `$(`$_.Exception.Message)"
        Write-Exit -Script "$scriptName"
    }
}

"@

        New-Item -Path "$scriptPath\$scriptName.ps1" -ItemType File -Force | Out-Null

        Add-Content -Path "$scriptPath\$scriptName.ps1" -Value $core
        Add-Content -Path "$scriptPath\$scriptName.ps1" -Value $framework
        Add-Content -Path "$scriptPath\$scriptName.ps1" -Value "Invoke-Script '$scriptName'"

        Start-Process powershell.exe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$scriptPath\$scriptName.ps1`"" -WorkingDirectory $pwd -Verb RunAs
    } catch {
        Write-Host "$($_.Exception.Message)"
    }
}

function Get-Script {
    param (
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$Target
    )
        
    $request = [System.Net.HttpWebRequest]::Create($Url)
    $response = $request.GetResponse()
  
    if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
        throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$Url'."
    }
  
    if ($Target -match '^\.\\') {
        $Target = Join-Path (Get-Location -PSProvider "FileSystem") ($Target -Split '^\.')[1]
    }
            
    if ($Target -and !(Split-Path $Target)) {
        $Target = Join-Path (Get-Location -PSProvider "FileSystem") $Target
    }

    if ($Target) {
        $fileDirectory = $([System.IO.Path]::GetDirectoryName($Target))
        if (!(Test-Path($fileDirectory))) {
            [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null
        }
    }
  
    [byte[]]$buffer = new-object byte[] 1048576

    $reader = $response.GetResponseStream()
    $writer = new-object System.IO.FileStream $Target, "Create"

    do {
        $count = $reader.Read($buffer, 0, $buffer.Length)
        $writer.Write($buffer, 0, $count)
    } while ($count -gt 0)                
}  

Invoke-This

$core = @"


"@
