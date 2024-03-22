function Invoke-This {
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
        Exit
    }
    
    $scriptName = "Edit-UserGroup"
    $scriptPath = $env:TEMP

    if (Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -ErrorAction SilentlyContinue) {
        $framework = Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -Raw
    } else {
        Get-Script -Url "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1" -Target "$scriptPath\CS-Framework.ps1"
        $framework = Get-Content -Path "$scriptPath\CS-Framework.ps1" -Raw
        Get-Item -ErrorAction SilentlyContinue "$scriptPath\CS-Framework.ps1" | Remove-Item -ErrorAction SilentlyContinue
    }

    $scriptDescription = @"
 This script allows you to modify the group membership of a user on a Windows system. 
 It provides menus for selecting the user and the desired group (Administrators or Users).
"@

    $core = @"
function $scriptName {
    try {
        Get-Item -ErrorAction SilentlyContinue "$scriptPath\$scriptName.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host "`n   Chaste Scripts: Edit User Group v0315240354"
        Write-Host "$scriptDescription" -ForegroundColor DarkGray

        `$username = Select-User

        Write-Text -Type "header" -Text "Select user group" -LineBefore -LineAfter
     
        `$groups = Get-LocalGroup | ForEach-Object {
            `$description = `$_.Description
            if (`$description.Length -gt 72) {
                `$description = `$description.Substring(0, 72) + "..."
            }
            @{ `$_.Name = `$description }
        } | Sort-Object -Property Name
        
        `$moreGroups = [ordered]@{}

        foreach (`$group in `$groups) {
            `$moreGroups += `$group
        }
        
        `$group = Get-Option -Options `$moreGroups -ReturnValue
        
        `$data = Get-AccountInfo -Username `$username

        Write-Text -Type "notice" -Text "You're about to change this users group membership." -LineBefore -LineAfter
        `$choice = Get-Option -Options `$([ordered]@{
            "Submit"  = "Confirm and apply." 
            "Reset"   = "Start over at the beginning."
            "Exit"    = "Run a different command."
        }) -LineAfter

        if (`$choice -ne 0 -and `$choice -ne 1 -and `$choice -ne 2) { $script }
        if (`$choice -eq 1) { Invoke-Script "$scriptName" }
        if (`$choice -eq 2) { Write-Exit -Script "$scriptName" }

        Remove-LocalGroupMember -Group "Administrators" -Member `$username -ErrorAction SilentlyContinue

        Add-LocalGroupMember -Group `$group -Member `$username -ErrorAction SilentlyContinue | Out-Null

        `$data = Get-AccountInfo `$username

        Write-Text -Type "list" -List `$data -LineAfter

        Write-Exit "The group membership for `$username has been changed to `$group." -Script "$scriptName"
    } catch {
        Write-Text -Type "error" -Text "Edit group error: `$(`$_.Exception.Message)"
        Write-Exit -Script "$script"
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