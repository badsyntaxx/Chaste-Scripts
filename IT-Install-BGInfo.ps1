function Invoke-This {
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
        Exit
    }
    
    $scriptName = "Install-BGInfo"
    $scriptPath = $env:TEMP

    if (Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -ErrorAction SilentlyContinue) {
        $framework = Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -Raw
    } else {
        Get-Script -Url "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1" -Target "$scriptPath\CS-Framework.ps1"
        $framework = Get-Content -Path "$scriptPath\CS-Framework.ps1" -Raw
        Get-Item -ErrorAction SilentlyContinue "$scriptPath\CS-Framework.ps1" | Remove-Item -ErrorAction SilentlyContinue
    }

    $scriptDescription = @"
 This function allows you to install BGInfo. Just paste a link to your BGInfo.zip.
"@

    $core = @"
function $scriptName {
    try {
        Get-Item -ErrorAction SilentlyContinue "$scriptPath\$scriptName.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host "`n Chaste Scripts: Install BGInfo v0317241028"
        Write-Host "$scriptDescription`n" -ForegroundColor DarkGray

        `$text = @(
            "What this script does."
            " "
            "1. Downloads a BGInfo.zip containing BGInfo install."
            "2. Opens the archive and copies the BGInfo folder to 'Program Files'."
            "3. Adds a 'Start BGInfo.bat' to the common startup folder."
            "4. Runs the .bat file and apply the background."
            " "
        )

        Write-Box -Text `$text

        `$options = (
            "Default",
            "Nuvia ISR"
        )

        `$choice = Get-Option -Options `$options -LineBefore -LineAfter

        if (`$choice -eq 0) { 
            `$url = "https://drive.google.com/uc?export=download&id=1wBYV4MFbC68YhIUFcFeul8iuMsy1Qo_N" 
            `$target = "Default" 
        }
        if (`$choice -eq 1) { 
            `$url = "https://drive.google.com/uc?export=download&id=18gFWHawWknKufHXjcmMUB0SwGoSlbBEk" 
            `$target = "NuviaISR" 
        }

        `$download = Get-Download -Url `$url -Target "C:\Windows\Temp\`$target_BGInfo.zip"

        if (!`$download) { Write-Exit -Script "$scriptName" }

        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallPaper -Value ""
        Set-ItemProperty -Path "HKCU:Control Panel\Colors" -Name Background -Value "0 0 0"

        Expand-Archive -LiteralPath "C:\Windows\Temp\`$target_BGInfo.zip" -DestinationPath "C:\Windows\Temp\"

        Remove-Item -Path "C:\Windows\Temp\`$target_BGInfo.zip" -Recurse

        ROBOCOPY "C:\Windows\Temp\BGInfo" "C:\Program Files\BGInfo" /E /NFL /NDL /NJH /NJS /nc /ns | Out-Null
        ROBOCOPY "C:\Windows\Temp\BGInfo" "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" "Start BGInfo.bat" /NFL /NDL /NJH /NJS /nc /ns | Out-Null

        Start-Process -FilePath "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\Start BGInfo.bat" -WindowStyle Hidden

        Remove-Item -Path "C:\Windows\Temp\BGInfo" -Recurse 

        Write-Host
        Write-Exit -Message "BGInfo installed and applied." -Script "$scriptName" -LineBefore
    } catch {
        Write-Text -Type "error" -Text "Install BGInfo error: `$(`$_.Exception.Message)"
        Write-Exit -Script "$scriptName"
    }
}

"@

    New-Item -Path "$scriptPath\$scriptName.ps1" -ItemType File -Force | Out-Null

    Add-Content -Path "$scriptPath\$scriptName.ps1" -Value $core
    Add-Content -Path "$scriptPath\$scriptName.ps1" -Value $framework
    Add-Content -Path "$scriptPath\$scriptName.ps1" -Value "Invoke-Script '$scriptName'"

    Start-Process powershell.exe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$scriptPath\$scriptName.ps1`"" -WorkingDirectory $pwd -Verb RunAs
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