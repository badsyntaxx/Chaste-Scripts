function Invoke-Script {
    param (
        [parameter(Mandatory = $false)]
        [string]$ScriptName
    ) 

    try {
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
            Exit;
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
    }
}

function Get-Input {
    param (
        [parameter(Mandatory = $false)]
        [string]$Value = "",
        [parameter(Mandatory = $false)]
        [string]$Prompt,
        [parameter(Mandatory = $false)]
        [regex]$Validate = $null,
        [parameter(Mandatory = $false)]
        [switch]$IsSecure = $false,
        [parameter(Mandatory = $false)]
        [switch]$CheckExistingUser = $false,
        [parameter(Mandatory = $false)]
        [switch]$LineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$LineAfter = $false
    )

    try {
        if ($LineBefore) { Write-Host }

        $currPos = $host.UI.RawUI.CursorPosition

        Write-Host "    $Prompt`:" -NoNewline 
        if ($IsSecure) { $userInput = Read-Host -AsSecureString } 
        else { $userInput = Read-Host }

        $errorMessage = ""

        if ($CheckExistingUser) {
            $account = Get-LocalUser -Name $userInput -ErrorAction SilentlyContinue
            if ($null -ne $account) { $errorMessage = "An account with that name already exists." }
        }

        if ($userInput -notmatch $Validate) {
            $errorMessage = "Invalid input. Please try again."
        } 

        if ($errorMessage -ne "") {
            Write-Text -Type "error" -Text $errorMessage
            if ($CheckExistingUser) {
                return Get-Input -Prompt $Prompt -Validate $Validate -CheckExistingUser
            } else {
                return Get-Input -Prompt $Prompt -Validate $Validate
            }
        }

        if ($userInput.Length -eq 0 -and $Value -ne "" -and !$IsSecure) {
            $userInput = $Value
        }

        [Console]::SetCursorPosition($currPos.X, $currPos.Y)
        
        Write-Host "  $([char]0x2713) " -ForegroundColor "Green" -NoNewline
        if ($IsSecure -and ($userInput.Length -eq 0)) {
            Write-Host "$Prompt`:                                                       "
        } else {
            Write-Host "$Prompt`:$userInput                                             "
        }

        if ($LineAfter) { Write-Host }
    
        return $userInput
    } catch {
        Write-Text -Type "error" -Text "Input Error: $($_.Exception.Message)"
    }
}

function Get-Option {
    param (
        [parameter(Mandatory = $true)]
        [array]$Options,
        [parameter(Mandatory = $false)]
        [int]$DefaultOption = 0,
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
  
        for ($i = 0; $i -le $Options.length; $i++) {
            if ($i -eq $pos) { 
                Write-Host "  $([char]0x203A) $($Options[$i])" -ForegroundColor "Cyan" 
            } else {
                if ($($Options[$i])) { Write-Host "    $($Options[$i])" -ForegroundColor "White" } 
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
            $menuOldPos = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen - $oldPos)))
            $menuNewPos = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen - $pos)))
      
            $host.UI.RawUI.CursorPosition = $menuOldPos
            Write-Host "    $($Options[$oldPos])" -ForegroundColor "White"
            $host.UI.RawUI.CursorPosition = $menuNewPos
            Write-Host "  $([char]0x203A) $($Options[$pos])" -ForegroundColor "Cyan"
            $host.UI.RawUI.CursorPosition = $currPos
        }

        if ($LineAfter) { Write-Host }
        return $pos
    } catch {
        Write-Host "  $($_.Exception.Message)" -ForegroundColor "Red"
        Read-Host "  Press any key to continue"
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

function Write-Box {
    param (
        [parameter(Mandatory = $false)]
        [array]$Text
    )

    $horizontalLine = [string][char]0x2500
    $verticalLine = [string][char]0x2502
    $topLeft = [string][char]0x250C
    $topRight = [string][char]0x2510
    $bottomLeft = [string][char]0x2514
    $bottomRight = [string][char]0x2518
    $longestString = $Text | Sort-Object Length -Descending | Select-Object -First 1
    $count = $longestString.Length

    Write-Host " $topLeft$($horizontalLine * ($count + 2))$topRight" -ForegroundColor Cyan

    foreach ($line in $Text) {
        Write-Host " $verticalLine" -ForegroundColor Cyan -NoNewline
        if ($line.Contains("http")) {
            Write-Host " $($line.PadRight($count))" -ForegroundColor DarkCyan -NoNewline
        } else {
            Write-Host " $($line.PadRight($count))" -ForegroundColor White -NoNewline
        }
        Write-Host " $verticalLine" -ForegroundColor Cyan
    }

    Write-Host " $bottomLeft$($horizontalLine * ($count + 2))$bottomRight" -ForegroundColor Cyan
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

    if ($Message -ne "") { Write-Text -Type "success" -Text $Message }

    $paths = @("$env:TEMP\$Script.ps1", "$env:SystemRoot\Temp\$Script.ps1")

    foreach ($p in $paths) { Get-Item -ErrorAction SilentlyContinue $p | Remove-Item -ErrorAction SilentlyContinue }

    $param = Read-Host -Prompt "`r`n  Enter command"

    Write-Host
    if ($param.Length -gt 0) {
        if ($param -eq "restart") { Invoke-Script $Script } 
        else { Invoke-RestMethod "chaste.dev$param" | Invoke-Expression -ErrorAction SilentlyContinue }
    } else {
        Exit
    }
}

function Get-Download {
    param (
        [parameter(Mandatory = $true)]
        [string]$Url,
        [parameter(Mandatory = $true)]
        [string]$Target,
        [parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        [parameter(Mandatory = $false)]
        [int]$Interval = 3
    )

    $downloadComplete = $true 
    Write-Text "Downloading..."

    Write-Text $Url
    Write-Text $Target
    
    for ($retryCount = 1; $retryCount -le $MaxRetries; $retryCount++) {
        try {
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFileAsync($Url, $Target)

            # Show progress bar
            $progressParams = @{
                Activity = "Downloading"
                Status = "In Progress"
                PercentComplete = 0
            }

            while ($wc.IsBusy) {
                $progressParams.PercentComplete = ($wc.BytesReceived / $wc.TotalBytesToReceive) * 100
                Write-Progress @progressParams
                Start-Sleep -Seconds 1
            }
        } catch {
            Write-Text -Type "fail" -Text "$($_.Exception.Message)"
            $downloadComplete = $false
            
            if ($retryCount -lt $MaxRetries) {
                Write-Host "Retrying..."
                Start-Sleep -Seconds $Interval
            } else {
                Write-Text -Type "error" -Text "Maximum retries reached. Download failed."
            }
        }
    }

    if ($downloadComplete) {
        Write-Host "Download complete."
        return $true
    } else {
        Remove-Item -ErrorAction SilentlyContinue $Target
        return $false
    }
}

function Select-User {
    try {
        Write-Text -Type "header" -Text "Select a user" -LineBefore -LineAfter

        $userNames = @()
        $accounts = @()
        $localUsers = Get-LocalUser
        $excludedAccounts = @("DefaultAccount", "WDAGUtilityAccount", "Guest", "defaultuser0")
        $adminEnabled = Get-LocalUser -Name "Administrator" | Select-Object -ExpandProperty Enabled

        if (!$adminEnabled) { $excludedAccounts += "Administrator" }

        foreach ($user in $localUsers) {
            if ($user.Name -notin $excludedAccounts) { $userNames += $user.Name }
        }

        $longestName = $userNames | Sort-Object { $_.Length } | Select-Object -Last 1

        foreach ($name in $userNames) {
            $username = Get-LocalUser -Name $name
            $length = $longestName.Length - $name.Length

            $spaces = ""
            for ($i = 0; $i -lt $length; $i++) { $spaces += " " }

            $groups = Get-LocalGroup | Where-Object { $username.SID -in ($_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name"
            $accounts += "$username $spaces - $($groups -join ';')" 
        }

        $choice = Get-Option -Options $accounts -LineAfter

        $data = Get-AccountInfo $userNames[$choice]

        Write-Text -Type "list" -List $data

        return $userNames[$choice]
    } catch {
        Write-Text -Type "error" -Text "Select user error: $($_.Exception.Message)"
    }
}

function Get-AccountInfo {
    param (
        [parameter(Mandatory = $true)]
        [string]$Username
    )

    try {
        $user = Get-LocalUser -Name $Username
        $groups = Get-LocalGroup | Where-Object { $user.SID -in ($_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name"
        $userProfile = Get-CimInstance Win32_UserProfile -Filter "SID = '$($user.SID)'"
        $dir = $userProfile.LocalPath
        if ($null -ne $userProfile) { $dir = $userProfile.LocalPath } else { $dir = "Awaiting first sign in." }

        $source = Get-LocalUser -Name $Username | Select-Object -ExpandProperty PrincipalSource

        $data = @(
            "Name:$Username"
            "Groups:$($groups -join ';')"
            "Path:$dir"
            "Source:$source"
        )

        return $data
    } catch {
        Write-Alert -Type "error" -Text "ERROR: $($_.Exception.Message)"
        Read-Host -Prompt "Press any key to continue"
    }
}