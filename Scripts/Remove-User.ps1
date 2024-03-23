if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

function Invoke-This {
    $scriptName = 'Remove-User'

    $scriptDescription = @"
 This function allows you to remove a user from a Windows system, with options 
 to delete or keep their user profile / data.
"@

    $core = @"
function $scriptName {
    try {
        Write-Welcome -File $scriptName.ps1 -Title "Remove User v0315241122" -Description `"$scriptDescription`"

        `$username = Select-User

        Write-Text -Type "header" -Text "Delete user data" -LineBefore -LineAfter
        `$choice = Get-Option -Options `$([ordered]@{
            "Delete"  = "Also delete the users data."
            "Keep"    = "Do not delete the users data."
        }) -LineAfter

        if (`$choice -eq 0) { `$deleteData = `$true }
        if (`$choice -eq 1) { `$deleteData = `$false }

        if (`$deleteData) {
            Write-Text -Type "notice" "You're about to delete this account and it's data!" -LineBefore -LineAfter
        } else {
            Write-Text -Type "notice" "You're about to delete this account!" -LineBefore -LineAfter
        }
        
        `$choice = Get-Option -Options `$([ordered]@{
            "Submit"  = "Confirm and apply." 
            "Reset"   = "Start over at the beginning."
            "Exit"    = "Run a different command."
        }) -LineAfter

        if (`$choice -ne 0 -and `$choice -ne 2) { Invoke-Script "$scriptName" }
        if (`$choice -eq 2) { Write-Exit -Script "$scriptName" }

        Remove-LocalUser -Name `$username | Out-Null

        `$user = Get-LocalUser -Name `$username -ErrorAction SilentlyContinue | Out-Null

        if (`$null -eq `$user) {
            Write-Text -Type "done" -Text "Local user removed."
        } else {
            Write-Text -Type "fail" -Text "Local user not removed." -LineBefore
        }
        
        if (`$deleteData) {
            `$userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '`$(`$user.SID)'"
            `$dir = `$userProfile.LocalPath
            if (`$null -ne `$dir -And (Test-Path -Path `$dir)) { 
                Remove-Item -Path `$dir -Recurse -Force 
                Write-Text -Type "done" -Text "User data deleted."
            } else {
                Write-Text -Type "done" -Text "No data found." -LineAfter
            }
        }

        Write-Exit -Message "The user has been deleted." -LineBefore -LineAfter -Script "$scriptName"
    } catch {
        Write-Text -Type "error" -Text "Remove User Error: `$(`$_.Exception.Message)"
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