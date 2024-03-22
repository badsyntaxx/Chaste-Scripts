function Select-Tool {
    $scriptDescription = @"
 This is the Chaste Scripts menu. Here you can select the various functions without
 typing out commands.
"@

    Write-Host "`n Chaste Scripts: Menu v0319241206"
    Write-Host "$scriptDescription" -ForegroundColor DarkGray
    Write-Host
    $options = [ordered]@{
        "Enable administrator" = "Toggle the Windows built in administrator account."
        "Add user"             = "Add a user to the system."
        "Remove user"          = "Remove a user from the system."
        "Edit user name"       = "Edit a users name."
        "Edit user password"   = "Edit a users password."
        "Edit user group"      = "Edit a users group membership."
        "Edit hostname"        = "Edit this computers name and description."
        "Edit network adapter" = "Edit a network adapter.(beta)"
    }

    Write-Text -Type "header" -Text "Selection" -LineAfter

    $choice = Get-Option -Options $options

    if ($choice -eq 0) { $script = "Enable-BuiltInAdminAccount.ps1" }
    if ($choice -eq 1) { $script = "Add-User.ps1" }
    if ($choice -eq 2) { $script = "Remove-User.ps1" }
    if ($choice -eq 3) { $script = "Edit-UserName.ps1" }
    if ($choice -eq 4) { $script = "Edit-UserPassword.ps1" }
    if ($choice -eq 5) { $script = "Edit-UserGroup.ps1" }
    if ($choice -eq 6) { $script = "Edit-Hostname.ps1" }
    if ($choice -eq 7) { $script = "Edit-NetworkAdapter.ps1" }

    Write-Text -Text "Initializing script..." -LineBefore
    
    Initialize-Action -Script $script
}

function Initialize-Action {
    param (
        [parameter(Mandatory = $true)]
        [string]$Script
    )

    try {
        $scriptPath = $env:TEMP

        Get-Script -Url "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-$Script" -Target "$scriptPath\$Script"
        $script = Get-Content -Path "$scriptPath\$Script" -Raw
        # Get-Item -ErrorAction SilentlyContinue "$scriptPath\$Script" | Remove-Item -ErrorAction SilentlyContinue
        
        Start-Process powershell.exe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$scriptPath\$Script`"" -WorkingDirectory $pwd -Verb RunAs
    } catch {
        Write-Text -Type "error" -Text "$($_.Exception.Message)"
        Write-Exit -Script "Menu"
    }
}

function Invoke-Script {
    param (
        [parameter(Mandatory = $false)]
        [string]$ScriptName
    )

    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
        Exit
    }  

    try {
        $console = $host.UI.RawUI
        $console.BackgroundColor = "Black"
        $console.ForegroundColor = "Gray"
        $console.WindowTitle = "Chaste Scripts"
        Clear-Host
        Invoke-Expression $ScriptName
    } catch {
        Write-Text -Type "error" -Text "Initialization Error: $($_.Exception.Message)"
        Write-Exit
    }
}

function Get-Option {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Options,
        [parameter(Mandatory = $false)]
        [int]$DefaultOption = 0,
        [parameter(Mandatory = $false)]
        [switch]$ReturnValue = $false,
        [parameter(Mandatory = $false)]
        [switch]$LineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$LineAfter = $false
    )

    try {
        if ($LineBefore) { Write-Host }
        $vkeycode = 0
        $pos = $DefaultOption
        $oldPos = 0
        $orderedKeys = $Options.Keys | ForEach-Object { $_ }
        $longestKeyLength = ($orderedKeys | Measure-Object -Property Length -Maximum).Maximum

        for ($i = 0; $i -lt $orderedKeys.Count; $i++) {
            $key = $orderedKeys[$i]
            $padding = " " * ($longestKeyLength - $key.Length)
            if ($i -eq $pos) { Write-Host "  $([char]0x203A) $key $padding - $($Options[$key])" -ForegroundColor "Cyan" } 
            else { Write-Host "    $key $padding - $($Options[$key])" -ForegroundColor "White" }
        }

        $currPos = $host.UI.RawUI.CursorPosition

        While ($vkeycode -ne 13) {
            $press = $host.ui.rawui.readkey("NoEcho, IncludeKeyDown")
            $vkeycode = $press.virtualkeycode
            Write-host "$($press.character)" -NoNewLine
            $oldPos = $pos;
            if ($vkeycode -eq 38) { $pos-- }
            if ($vkeycode -eq 40) { $pos++ }

            if ($pos -lt 0) { $pos = 0 }
            if ($pos -ge $orderedKeys.Count) { $pos = $orderedKeys.Count - 1 }

            $menuLen = $orderedKeys.Count
            $menuOldPos = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen - $oldPos)))
            $menuNewPos = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen - $pos)))
            $oldKey = $orderedKeys[$oldPos]
            $newKey = $orderedKeys[$pos]
            
            $host.UI.RawUI.CursorPosition = $menuOldPos
            Write-Host "    $($orderedKeys[$oldPos]) $(" " * ($longestKeyLength - $oldKey.Length)) - $($Options[$orderedKeys[$oldPos]])" -ForegroundColor "White"
            $host.UI.RawUI.CursorPosition = $menuNewPos
            Write-Host "  $([char]0x203A) $($orderedKeys[$pos]) $(" " * ($longestKeyLength - $newKey.Length)) - $($Options[$orderedKeys[$pos]])" -ForegroundColor "Cyan"
            $host.UI.RawUI.CursorPosition = $currPos
        }

        if ($LineAfter) { Write-Host }
        if ($ReturnValue) { return $orderedKeys[$pos] } else { return $pos }
    } catch {
        Write-Host "  $($_.Exception.Message)" -ForegroundColor "Red"
        Write-Exit
    }
}

function Write-Text {
    param (
        [parameter(Mandatory = $false)]
        [string]$Text,
        [parameter(Mandatory = $false)]
        [string]$Type = "plain",
        [parameter(Mandatory = $false)]
        [switch]$LineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$LineAfter = $false,
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$Data
    )

    if ($LineBefore) { Write-Host }
    if ($Type -eq "header") { Write-Host "   $Text" -ForegroundColor "DarkCyan" }
    if ($Type -eq "header") { 
        $lines = ""
        for ($i = 0; $i -lt 50; $i++) { $lines += "$([char]0x2500)" }
        Write-Host "   $lines" -ForegroundColor "DarkCyan"
    }
    if ($Type -eq 'done') { 
        Write-Host " $([char]0x2713)" -ForegroundColor "Green" -NoNewline
        Write-Host " $Text" 
    }
    if ($Type -eq 'fail') { 
        Write-Host " X " -ForegroundColor "Red" -NoNewline
        Write-Host "$Text" 
    }
    if ($Type -eq 'success') { Write-Host " $([char]0x2713) $Text" -ForegroundColor "Green" }
    if ($Type -eq 'error') { Write-Host "   $Text" -ForegroundColor "Red" }
    if ($Type -eq 'notice') { Write-Host "   $Text" -ForegroundColor "Yellow" }
    if ($Type -eq 'plain') { Write-Host "   $Text" }
    if ($Type -eq 'recap') {
        foreach ($key in $Data.Keys) { 
            $value = $Data[$key]
            if ($value.Length -gt 0) {
                Write-Host "   $key`:$value" -ForegroundColor "DarkGray" 
            } else {
                Write-Host "   $key`:" -ForegroundColor "Magenta" 
            }
        }
    }
    if ($LineAfter) { Write-Host }
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

Invoke-Script "Select-Tool"