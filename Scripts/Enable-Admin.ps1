if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

function Invoke-This {
    $scriptName = 'Enable-Admin'

    $scriptDescription = @"
 This script allows you to toggle the built in admin account on a Windows system. 
 It provides an interactive menu for you to enable or disable the account.
"@

    $core = @"
function $scriptName {
    try { 
        Write-Welcome -File $scriptName.ps1 -Title "Enable Administrator v0315241122" -Description `"$scriptDescription`"

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

    New-Item -Path "$env:TEMP\$scriptName.ps1" -ItemType File -Force | Out-Null

    $dependencies = @(
        'Global'
        'Get-Input'
        'Get-Option'
        'Get-UserData'
    )

    foreach ($dependency in $dependencies) {
        Get-Script -Url "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/Framework/$dependency.ps1" -Target "$env:TEMP\$dependency.ps1" | Out-Null
        $rawScript = Get-Content -Path "$env:TEMP\$dependency.ps1" -Raw
        Add-Content -Path "$env:TEMP\$scriptName.ps1" -Value $rawScript
        Get-Item -ErrorAction SilentlyContinue "$env:TEMP\$dependency.ps1" | Remove-Item -ErrorAction SilentlyContinue
    }

    Add-Content -Path "$env:TEMP\$scriptName.ps1" -Value $core
    Add-Content -Path "$env:TEMP\$scriptName.ps1" -Value "Invoke-Script '$scriptName'"

    Start-Process powershell.exe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$env:TEMP\$scriptName.ps1`"" -WorkingDirectory $pwd -Verb RunAs
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