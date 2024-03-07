

function Select-Tool {
    Write-Host "Chase's Windows Tools`n" -ForegroundColor DarkGray
    Write-Text -Type "heading" -Text "Chase's Windows Tools"
    Write-Text -Type "subheading" -Text "Select a tool"

    $options = @(
        "Create InTechAdmin       - Create the InTechAdmin account.",
        "Install Nuvia ISR Apps   - Create a local user.",
        "Quit                     - Do nothing and exit."
    )

    $choice = Get-Option -Options $options

    if ($choice -eq 0) { $script = "ITT-Add-InTechAdmin.ps1" }
    if ($choice -eq 1) { $script = "ITT-Install-ISRApps.ps1" }
    if ($choice -eq 2) { $script = "ITT-Add-ISRBookmarks.ps1" }
    if ($choice -eq 4) { Exit }

    Write-Text -Type "subheading" -Text "Initializing script" -LineBefore
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
        $isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
        $path = if ($isAdmin) { "$env:SystemRoot\Temp" } else { "$env:TEMP" }
        Write-Text -Text "Path: $path"
        Write-Text -Text "File: $Script"
        
        $url = "https://raw.githubusercontent.com/badsyntaxx/Chases-Windows-Scripts/main/"
        $download = Get-Download -Url "$url/$script" -Output "$path\$script"
        if ($download) { 
            Write-Text -Type "done" -Text "Script ready..."
            PowerShell.exe -File "$path\$script"
        }
    } catch {
        Write-Text -Text "$($_.Exception.Message)" -Type "error"
        Read-Host "   Press any key to continue"
    }
}

function Get-Download {
    param (
        [parameter(Mandatory = $true)]
        [string]$Url,
        [parameter(Mandatory = $true)]
        [string]$Output,
        [parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        [parameter(Mandatory = $false)]
        [int]$Interval = 3
    )

    for ($retryCount = 1; $retryCount -le $MaxRetries; $retryCount++) {
        try {
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($Url, "$Output")
            Write-Text -Type "done" -Text "Script downloaded."
            return $true
        } catch {
            Write-Text -Type "error" -Text "$($_.Exception.Message)"
            if ($retryCount -lt $MaxRetries) {
                Start-Sleep -Seconds $Interval
            } else {
                Write-Text -Type "error" -Text "Maximum retries reached. Initialization failed."
                Read-Host "   Press any key to continue"
            }
        }
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
        $console.WindowTitle = "Chase's Windows Tools"
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
        [array]$Options
    )

    try {
        $vkeycode = 0
        $pos = 0
        $oldPos = 0
        $fcolor = $host.UI.RawUI.ForegroundColor
        $bcolor = $host.UI.RawUI.BackgroundColor
  
        for ($i = 0; $i -le $Options.length; $i++) {
            if ($i -eq $pos) {
                Write-Host "   $($Options[$i])" -ForegroundColor $bcolor -BackgroundColor $fcolor 
            } else {
                if ($($Options[$i])) {
                    Write-Host "   $($Options[$i])" -ForegroundColor $fcolor -BackgroundColor $bcolor
                } 
            }
        }

        $currPos = $host.UI.RawUI.CursorPosition
        While ($vkeycode -ne 13) {
            $press = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown")
            $vkeycode = $press.virtualkeycode
            Write-host "$($press.character)" -NoNewLine
            $oldPos = $pos;
            If ($vkeycode -eq 38) { $pos-- }
            If ($vkeycode -eq 40) { $pos++ }
            if ($pos -lt 0) { $pos = 0 }
            if ($pos -ge $Options.length) { $pos = $Options.length - 1 }

            $menuLen = $Options.Count
            $fcolor = $host.UI.RawUI.ForegroundColor
            $bcolor = $host.UI.RawUI.BackgroundColor
            $menuOldPos = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen - $oldPos)))
            $menuNewPos = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen - $pos)))
      
            $host.UI.RawUI.CursorPosition = $menuOldPos
            Write-Host "   $($Options[$oldPos])" -ForegroundColor $fcolor -BackgroundColor $bcolor 
            $host.UI.RawUI.CursorPosition = $menuNewPos
            Write-Host "   $($Options[$pos])" -ForegroundColor $bcolor -BackgroundColor $fcolor 
            $host.UI.RawUI.CursorPosition = $currPos
        }
        return $pos
    } catch {
        Write-Text -Text "$($_.Exception.Message)" -Type "error"
        Read-Host "   Press any key to continue"
    }
}

function Write-Text {
    param (
        [parameter(Mandatory = $true)]
        [string]$Text,
        [parameter(Mandatory = $false)]
        [string]$Type = "plain",
        [parameter(Mandatory = $false)]
        [switch]$LineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$LineAfter = $false
    )

    if ($LineBefore) { Write-Host }
    if ($Type -eq "heading") { Write-Host " $Text" -ForegroundColor "Cyan" }
    if ($Type -eq "heading") { 
        $lines = ""
        for ($i = 0; $i -lt 70; $i++) { $lines += "$([char]0x2500)" }
        Write-Host "$lines`n" -ForegroundColor Cyan
    }
    if ($Type -eq 'done') { 
        Write-Host " $([char]0x2713)" -ForegroundColor "Green" -NoNewline
        Write-Host " $Text" 
    }
    if ($Type -eq "subheading") { Write-Host " $([char]0x203A) $Text" -ForegroundColor "Cyan" }
    if ($Type -eq 'success') { Write-Host " $([char]0x2713) $Text" -ForegroundColor "Green" }
    if ($Type -eq 'error') { Write-Host "   $Text" -ForegroundColor "Red" }
    if ($Type -eq 'notice') { Write-Host "   $Text" -ForegroundColor "Yellow" }
    if ($Type -eq 'plain') { Write-Host "   $Text" }
    if ($LineAfter) { Write-Host }
}

Initialize-Script "Select-Tool"