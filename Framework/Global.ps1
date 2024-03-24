function Invoke-Script {
    param (
        [parameter(Mandatory = $false)]
        [string]$ScriptName
    ) 

    try {
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
            Exit
        }

        # $height = 35
        # $width = 110
        $console = $host.UI.RawUI
        # $consoleBuffer = $console.BufferSize
        # $consoleSize = $console.WindowSize
        # $currentWidth = $consoleSize.Width
        # $currentHeight = $consoleSize.Height
        # if ($consoleBuffer.Width -gt $Width ) { $currentWidth = $Width }
        # if ($consoleBuffer.Height -gt $Height ) { $currentHeight = $Height }
        # $console.WindowPosition = New-Object System.Management.Automation.Host.Coordinates(0, 0)
        # $console.WindowSize = New-Object System.Management.Automation.Host.size($currentWidth, $currentHeight)
        # $console.BufferSize = New-Object System.Management.Automation.Host.size($Width, 9001)
        # $console.WindowSize = New-Object System.Management.Automation.Host.size($Width, $Height)
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

function Get-Command {
    try {
        $command = Get-Input -LineBefore
        $command = $command -replace ' ', '/'
        
        Invoke-Restmethod "chaste.dev/$command" | Invoke-Expression
    } catch {
        Write-Text -Type "error" -Text "$($_.Exception.Message)" -LineBefore -LineAfter
        Get-Command
    }
}

function Write-Text {
    param (
        [parameter(Mandatory = $false)]
        [string]$Text,
        [parameter(Mandatory = $false)]
        [string]$Type = "plain",
        [parameter(Mandatory = $false)]
        [string]$Color = "White",
        [parameter(Mandatory = $false)]
        [switch]$LineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$LineAfter = $false,
        [parameter(Mandatory = $false)]
        [array]$List,
        [parameter(Mandatory = $false)]
        [string]$OldData,
        [parameter(Mandatory = $false)]
        [string]$NewData
    )

    if ($LineBefore) { Write-Host }
    if ($Type -eq "header") { Write-Host " ## $Text" -ForegroundColor "DarkCyan" }
    if ($Type -eq 'done') { 
        Write-Host "  $([char]0x2713)" -ForegroundColor "Green" -NoNewline
        Write-Host " $Text" 
    }
    if ($Type -eq 'compare') { 
        Write-Host "   $OldData" -ForegroundColor "DarkGray" -NoNewline
        Write-Host " $([char]0x2192) " -ForegroundColor "Magenta" -NoNewline
        Write-Host "$NewData" -ForegroundColor "White"
    }
    if ($Type -eq 'fail') { 
        Write-Host "  X " -ForegroundColor "Red" -NoNewline
        Write-Host "$Text" 
    }
    if ($Type -eq 'success') { Write-Host "  $([char]0x2713) $Text" -ForegroundColor "Green" }
    if ($Type -eq 'error') { Write-Host "  X $Text" -ForegroundColor "Red" }
    if ($Type -eq 'notice') { Write-Host " ## $Text" -ForegroundColor "Yellow" }
    if ($Type -eq 'plain') { Write-Host "    $Text" -ForegroundColor $Color }
    if ($Type -eq 'list') {
        foreach ($item in $List) { Write-Host "    $item" -ForegroundColor "DarkGray" }
    }
    if ($LineAfter) { Write-Host }
}

function Write-Welcome {
    param (
        [parameter(Mandatory = $true)]
        [string]$Title,
        [parameter(Mandatory = $true)]
        [string]$Description,
        [parameter(Mandatory = $false)]
        [string]$Command
    )

    # Get-Item -ErrorAction SilentlyContinue "$env:TEMP\Chaste-Script.ps1" | Remove-Item -ErrorAction SilentlyContinue
    Write-Host
    Write-Host " Chaste Scripts: $Title"
    Write-Host " Command:"  -ForegroundColor DarkGray -NoNewline
    Write-Host " $Command" -ForegroundColor DarkGreen -NoNewline
    Write-Host " | $Description" -ForegroundColor DarkGray
}

function Write-Exit {
    param (
        [parameter(Mandatory = $false)]
        [string]$Message = "",
        [parameter(Mandatory = $false)]
        [string]$Script = "",
        [parameter(Mandatory = $false)]
        [switch]$LineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$LineAfter = $false
    )

    if ($Message -ne "") { Write-Text -Type "success" -Text $Message -LineAfter }

    $choice = Get-Option -Options $([ordered]@{
            'Again' = 'Start over and run this task again.'
            'Exit'  = 'Exit this function but stay in Chaste Scripts'
        })

    if ($choice -eq 0) { Invoke-Script $Script }

    Get-Command
}