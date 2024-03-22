function Invoke-This {
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
        Exit
    }
    
    $scriptName = "Remove-User"
    $scriptPath = $env:TEMP

    if (Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -ErrorAction SilentlyContinue) {
        $framework = Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -Raw
    } else {
        Get-Script -Url "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1" -Target "$scriptPath\CS-Framework.ps1"
        $framework = Get-Content -Path "$scriptPath\CS-Framework.ps1" -Raw
        Get-Item -ErrorAction SilentlyContinue "$scriptPath\CS-Framework.ps1" | Remove-Item -ErrorAction SilentlyContinue
    }

    $scriptDescription = @"
 This function allows you to remove a user from a Windows system, with options 
 to delete or keep their user profile / data.
"@

    $core = @"
function $scriptName {
    try {
        Get-Item -ErrorAction SilentlyContinue "$scriptPath\$scriptName.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host "`n   Chaste Scripts: Remove User v0315241122"
        Write-Host "$scriptDescription" -ForegroundColor DarkGray

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