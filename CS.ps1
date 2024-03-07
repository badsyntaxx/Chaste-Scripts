

function Select-Tool {
    Write-Host "Chaste Scripts`n" -ForegroundColor DarkGray

    $options = @(
        "Enable Administrator   - Enable Windows built in administrator account."
        "Create user            - Create a local user."
        "Edit user              - Edit / delete existing user."
        "Rename computer        - Edit this computers name and description."
        "Edit Network Adapter   - Select and edit a network adapter."
        "Quit                   - Do nothing and exit."
    )

    Write-Text -Type "header" -Text "Selection"

    $choice = Get-Option -Options $options

    if ($choice -eq 0) { $script = "CS-Enable-BuiltInAdminAccount.ps1" }
    if ($choice -eq 1) { $script = "CS-Add-LocalUser.ps1" }
    if ($choice -eq 2) { $script = "CS-Edit-LocalUser.ps1" }
    if ($choice -eq 3) { $script = "CS-Set-ComputerName.ps1" }
    if ($choice -eq 4) { $script = "CS-Edit-NetworkAdapter.ps1" }
    if ($choice -eq 5) { Exit }

    Write-Text -Text "Initializing script..." -LineBefore
    Initialize-Action -Script $script -Choice $choice
}

function Initialize-Action {
    param (
        [parameter(Mandatory = $true)]
        [string]$Script,
        [parameter(Mandatory = $true)]
        [string]$Choice
    )

    try {
        Invoke-RestMethod -Uri "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/$Script" | Invoke-Expression
    } catch {
        Write-Text -Type "error" -Text "$($_.Exception.Message)"
        Read-Host "   Press any key to continue"
    }
}

function Get-Download {
    param (
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$Files,
        [parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        [parameter(Mandatory = $false)]
        [int]$Interval = 3
    )

    $downloadComplete = $true 
    Write-Text -Text "Downloading..."
    foreach ($q in $Files.Keys) { 
        for ($retryCount = 1; $retryCount -le $MaxRetries; $retryCount++) {
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($Files[$q], $q)
            } catch {
                Write-Text -Type "fail" -Text "$($_.Exception.Message)"
                $downloadComplete = $false
                if ($retryCount -lt $MaxRetries) {
                    Write-Text -Text "Retrying..."
                    Start-Sleep -Seconds $Interval
                } else {
                    Write-Text -Type "error" -Text "Maximum retries reached. Download failed."
                }
            }
        }
    }

    if ($downloadComplete) {
        Write-Text -Type "done" -Text "Download complete."
        return $true
    } else {
        foreach ($q in $Files.Keys) { 
            Get-Item -ErrorAction SilentlyContinue $q | Remove-Item -ErrorAction SilentlyContinue 
        }
        return $false
    }
}

function Initialize-Script {
    param (
        [parameter(Mandatory = $false)]
        [string]$ScriptName
    )

    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
        Exit;
    }  

    try {
        $height = 37
        $width = 110
        $console = $host.UI.RawUI
        $consoleBuffer = $console.BufferSize
        $consoleSize = $console.WindowSize
        $currentWidth = $consoleSize.Width
        $currentHeight = $consoleSize.Height
        if ($consoleBuffer.Width -gt $Width ) { $currentWidth = $Width }
        if ($consoleBuffer.Height -gt $Height ) { $currentHeight = $Height }

        $console.WindowSize = New-Object System.Management.Automation.Host.size($currentWidth, $currentHeight)
        $console.BufferSize = New-Object System.Management.Automation.Host.size($Width, 2000)
        $console.WindowSize = New-Object System.Management.Automation.Host.size($Width, $Height)
        $console.BackgroundColor = "Black"
        $console.ForegroundColor = "Gray"
        $console.WindowTitle = "Chaste Scripts"
        Clear-Host
        Invoke-Expression $ScriptName
    } catch {
        Write-Text -Type "error" -Text "Initialization Error: $($_.Exception.Message)"
        Read-Host "   Press any key to continue"
    }
}

function Get-Option {
    param (
        [parameter(Mandatory = $true)]
        [array]$Options,
        [parameter(Mandatory = $false)]
        [int]$DefaultOption = 0
    )

    try {
        $vkeycode = 0
        $pos = $DefaultOption
        $oldPos = 0
        $fcolor = $host.UI.RawUI.ForegroundColor
  
        for ($i = 0; $i -le $Options.length; $i++) {
            if ($i -eq $pos) {
                Write-Host " $([char]0x203A) $($Options[$i])" -ForegroundColor "Cyan"
            } else {
                if ($($Options[$i])) {
                    Write-Host "   $($Options[$i])" -ForegroundColor $fcolor
                } 
            }
        }

        $currPos = $host.UI.RawUI.CursorPosition
        While ($vkeycode -ne 13) {
            $press = $host.ui.rawui.readkey("NoEcho, IncludeKeyDown")
            $vkeycode = $press.virtualkeycode
            Write-host "$($press.character)" -NoNewLine
            $oldPos = $pos;
            If ($vkeycode -eq 38) { $pos-- }
            If ($vkeycode -eq 40) { $pos++ }
            if ($pos -lt 0) { $pos = 0 }
            if ($pos -ge $Options.length) { $pos = $Options.length - 1 }

            $menuLen = $Options.Count
            $fcolor = $host.UI.RawUI.ForegroundColor
            $menuOldPos = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen - $oldPos)))
            $menuNewPos = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen - $pos)))
      
            $host.UI.RawUI.CursorPosition = $menuOldPos
            Write-Host "   $($Options[$oldPos])" -ForegroundColor $fcolor
            $host.UI.RawUI.CursorPosition = $menuNewPos
            Write-Host " $([char]0x203A) $($Options[$pos])" -ForegroundColor "Cyan"
            $host.UI.RawUI.CursorPosition = $currPos
        }
        Write-Output $pos
    } catch {
        Write-Host "   $($_.Exception.Message)" -ForegroundColor "Red"
        Read-Host "   Press any key to continue"
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

Initialize-Script "Select-Tool"