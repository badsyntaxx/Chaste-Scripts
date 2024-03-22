function Invoke-This {
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
        Exit
    }
    
    $scriptName = "Add-LocalUser"
    $scriptPath = $env:TEMP

    if (Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -ErrorAction SilentlyContinue) {
        $framework = Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -Raw
    } else {
        Get-Script -Url "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1" -Target "$scriptPath\CS-Framework.ps1"
        $framework = Get-Content -Path "$scriptPath\CS-Framework.ps1" -Raw
        Get-Item -ErrorAction SilentlyContinue "$scriptPath\CS-Framework.ps1" | Remove-Item -ErrorAction SilentlyContinue
    }

    $scriptDescription = @"
 This function creates a new local user account on a Windows system with specified settings, 
 including the username, optional password, and group. The account and password never expire.
"@

    $core = @"
function $scriptName {
    try {
        Get-Item -ErrorAction SilentlyContinue "$scriptPath\$scriptName.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host "`n Chaste Scripts: Add User v0315241122"
        Write-Host "$scriptDescription" -ForegroundColor DarkGray

        Write-Text -Type "header" -Text "Enter name" -LineBefore -LineAfter
        `$name = Get-Input -Prompt "" -Validate "^([a-zA-Z0-9 _\-]{1,64})$"  -CheckExistingUser

        Write-Text -Type "header" -Text "Enter password" -LineBefore -LineAfter
        `$password = Get-Input -Prompt "" -IsSecure
        
        Write-Text -Type "header" -Text "Set group membership" -LineBefore -LineAfter
        `$group = Get-Option -Options `$([ordered]@{
            'Administrators' = 'Set this users group membership to administrators.'
            'Users'          = 'Set this users group membership to standard users.' 
        }) -ReturnValue -LineAfter

        Write-Text -Type "notice" -Text "You're about to create a new local user!" -LineBefore -LineAfter
        `$choice = Get-Option -Options `$([ordered]@{
            "Submit"  = "Confirm and apply." 
            "Reset"   = "Start over at the beginning."
            "Exit"    = "Run a different command."
        }) -LineAfter

        if (`$choice -ne 0 -and `$choice -ne 2) { Invoke-Script "$scriptName" }
        if (`$choice -eq 2) {  Write-Exit -Script "$scriptName" }

        New-LocalUser `$name -Password `$password -Description "Local User" -AccountNeverExpires -PasswordNeverExpires -ErrorAction Stop | Out-Null
        Add-LocalGroupMember -Group `$group -Member `$name -ErrorAction Stop

        `$newUserName = Get-LocalUser -Name `$name | Select-Object -ExpandProperty Name
        `$data = Get-AccountInfo `$newUserName

        Write-Text -Type "list" -List `$data -LineAfter

        if (`$null -ne `$newUserName) { Write-Exit -Message "The user account was created." -Script "$scriptName" } 
        else { throw "There was an unknown error when creating the user." }
    } catch {
        Write-Text -Type "error" -Text "Add user error: `$(`$_.Exception.Message)"
        Write-Exit
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