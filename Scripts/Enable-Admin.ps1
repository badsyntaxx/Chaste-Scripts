function Invoke-This {
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
        Exit
    }
    
    $scriptName = "Enable-Admin"
    $scriptPath = $env:TEMP

    if (Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -ErrorAction SilentlyContinue) {
        $framework = Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -Raw
    } else {
        Get-Script -Url "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1" -Target "$scriptPath\CS-Framework.ps1"
        $framework = Get-Content -Path "$scriptPath\CS-Framework.ps1" -Raw
        Get-Item -ErrorAction SilentlyContinue "$scriptPath\CS-Framework.ps1" | Remove-Item -ErrorAction SilentlyContinue
    }

    $scriptDescription = @"
 This script allows you to toggle the built in admin account on a Windows system. 
 It provides an interactive menu for you to enable or disable the account.
"@

    $core = @"
function $scriptName {
    try { 
        Get-Item -ErrorAction SilentlyContinue "$scriptPath\$scriptName.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host "`n   Chaste Scripts: Edit User Name v0315240404"
        Write-Host "$scriptDescription" -ForegroundColor DarkGray

        Write-Text -Type "header" -Text "Toggle admin account" -LineBefore -LineAfter
        `$admin = Get-LocalUser -Name "Administrator"

        Write-Host "    Administrator:" -NoNewLine

        if (`$admin.Enabled) { Write-Host "Enabled" -ForegroundColor Yellow} 
        else { Write-Host "Disabled" -ForegroundColor Yellow }
        
        `$choice = Get-Option -Options `$([ordered]@{
            "Enable"   = "Enable the Windows built in administrator account."
            "Disable"  = "Disable the built in administrator account."
        }) -LineAfter -LineBefore

        if (`$choice -ne 0 -and `$choice -ne 1) { $scriptName }

        if (`$choice -eq 0) { 
            Get-LocalUser -Name "Administrator" | Enable-LocalUser 
            `$message = "Administrator account enabled."
        } 

        if (`$choice -eq 1) { 
            Get-LocalUser -Name "Administrator" | Disable-LocalUser 
            `$message = "Administrator account Disabled."
        }

        Write-Exit -Message `$message -Script "$scriptName"
    } catch {
        Write-Text -Type "error" -Text "Enable admin error: `$(`$_.Exception.Message)"
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
    
    try {
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $response = $request.GetResponse()
  
        if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
            throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$Url'."
        }

        [byte[]]$buffer = new-object byte[] 1048576
        [long]$total = [long]$count = 0
  
        $reader = $response.GetResponseStream()
        $writer = new-object System.IO.FileStream $Target, "Create"
  
        do {
            $count = $reader.Read($buffer, 0, $buffer.Length)
            $writer.Write($buffer, 0, $count)
            $total += $count
        } while ($count -gt 0)
        if ($count -eq 0) { return $true } else { return $false }
    } catch {
        Write-Host "Loading failed..."
            
        if ($retryCount -lt $MaxRetries) {
            Write-Host "Retrying..."
            Start-Sleep -Seconds $Interval
        } else {
            Write-Host "Maximum retries reached. Loading failed."
        }
    } finally {
        if ($reader) { $reader.Close() }
        if ($writer) { $writer.Flush(); $writer.Close() }
        [GC]::Collect()
    } 
}   

Invoke-This