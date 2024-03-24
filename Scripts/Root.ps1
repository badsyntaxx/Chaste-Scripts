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

        $console = $host.UI.RawUI
        $console.BackgroundColor = "Black"
        $console.ForegroundColor = "Gray"
        $console.WindowTitle = "Chaste Scripts"
        Clear-Host
        Write-Welcome -File "Root.ps1" -Title "Chaste Scripts" -Description " Enter commands."
        Invoke-Expression $ScriptName
    } catch {
        Write-Text -Type "error" -Text "Initialization Error: $($_.Exception.Message)"
        Write-Exit
    }
}

function Get-Command {
    try {
        $command = Get-Input -LineBefore
        $makeTitleCase = (Get-Culture).TextInfo.ToTitleCase($command)
        $addDash = $makeTitleCase -split '\s+', 2, "RegexMatch" -join '-'
        $fileFunc = $addDash -replace ' ', ''

        New-Item -Path "$env:TEMP\Chaste-Script.ps1" -ItemType File -Force | Out-Null

        $url = "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/"
        $dependencies = @( "$fileFunc", "Global", "Get-Input", "Get-Option", "Get-UserData", "Get-Download", "Select-User")
        $subPath = "Framework"

        foreach ($dependency in $dependencies) {
            if ($dependency -eq $fileFunc) { $subPath = "Scripts" }
            if ($dependency -eq 'Reclaim') { $subPath = "Plugins" }
            Get-Script -Url "$url/$subPath/$dependency.ps1" -Target "$env:TEMP\$dependency.ps1" | Out-Null
            $rawScript = Get-Content -Path "$env:TEMP\$dependency.ps1" -Raw
            Add-Content -Path "$env:TEMP\Chaste-Script.ps1" -Value $rawScript
            Get-Item -ErrorAction SilentlyContinue "$env:TEMP\$dependency.ps1" | Remove-Item -ErrorAction SilentlyContinue
            if ($subPath -eq 'Plugins') { break }
        }

        if ($subPath -ne 'Plugins') {
            Add-Content -Path "$env:TEMP\Chaste-Script.ps1" -Value "Invoke-Script '$fileFunc'"
        }

        Start-Process powershell.exe "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$env:TEMP\Chaste-Script.ps1`"" -WorkingDirectory $pwd -Verb RunAs
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
        [string]$File,
        [parameter(Mandatory = $true)]
        [string]$Title,
        [parameter(Mandatory = $true)]
        [string]$Description
    )

    Get-Item -ErrorAction SilentlyContinue "$env:TEMP\$File" | Remove-Item -ErrorAction SilentlyContinue
    Write-Host
    Write-Host " Chaste Scripts: $Title"
    Write-Host "$Description" -ForegroundColor DarkGray
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

    if ($choice -eq 0) {
        Invoke-Script $Script
    }

    Get-Command
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

        Write-Host "  > $Prompt" -NoNewline 
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
            Write-Host "$Prompt                                                       "
        } else {
            Write-Host "$Prompt$userInput                                             "
        }

        if ($LineAfter) { Write-Host }
    
        return $userInput
    } catch {
        Write-Text -Type "error" -Text "Input Error: $($_.Exception.Message)"
    }
}

function Get-Script {
    param (
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$Target,
        [parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        [parameter(Mandatory = $false)]
        [int]$Interval = 3
    )
    Begin {
        function Show-Progress {
            param (
                [Parameter(Mandatory)]
                [Single]$TotalValue,
                [Parameter(Mandatory)]
                [Single]$CurrentValue,
                [Parameter(Mandatory)]
                [string]$ProgressText,
                [Parameter()]
                [string]$ValueSuffix,
                [Parameter()]
                [int]$BarSize = 40,
                [Parameter()]
                [switch]$Complete
            )
            
            # calc %
            $percent = $CurrentValue / $TotalValue
            $percentComplete = $percent * 100
            if ($ValueSuffix) {
                $ValueSuffix = " $ValueSuffix" # add space in front
            }
  
            # build progressbar with string function
            $curBarSize = $BarSize * $percent
            $progbar = ""
            $progbar = $progbar.PadRight($curBarSize, [char]9608)
            $progbar = $progbar.PadRight($BarSize, [char]9617)

            if (!$Complete.IsPresent) {
                Write-Host -NoNewLine "`r    $ProgressText $progbar $($percentComplete.ToString("##0.00").PadLeft(6))%"
            } else {
                Write-Host -NoNewLine "`r    $ProgressText $progbar $($percentComplete.ToString("##0.00").PadLeft(6))%"                    
            }              
             
        }
    }
    Process {
        $downloadComplete = $true 
        for ($retryCount = 1; $retryCount -le $MaxRetries; $retryCount++) {
            try {
                $storeEAP = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'
        
                # invoke request
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

                [long]$fullSize = $response.ContentLength
                $fullSizeMB = $fullSize / 1024 / 1024
  
                # define buffer
                [byte[]]$buffer = new-object byte[] 1048576
                [long]$total = [long]$count = 0
  
                # create reader / writer
                $reader = $response.GetResponseStream()
                $writer = new-object System.IO.FileStream $Target, "Create"
  
                # start download
                $finalBarCount = 0 #show final bar only one time
                do {
                    $count = $reader.Read($buffer, 0, $buffer.Length)
          
                    $writer.Write($buffer, 0, $count)
              
                    $total += $count
                    $totalMB = $total / 1024 / 1024
          
                    if ($fullSize -gt 0) {
                        Show-Progress -TotalValue $fullSizeMB -CurrentValue $totalMB -ProgressText "Loading" -ValueSuffix "MB"
                    }

                    if ($total -eq $fullSize -and $count -eq 0 -and $finalBarCount -eq 0) {
                        Show-Progress -TotalValue $fullSizeMB -CurrentValue $totalMB -ProgressText "Loading" -ValueSuffix "MB" -Complete
                        $finalBarCount++
                    }
                } while ($count -gt 0)
                Write-Host
                if ($downloadComplete) { return $true } else { return $false }
            } catch {
                # Write-Text -Type "fail" -Text "$($_.Exception.Message)"
                Write-Text -Type "fail" -Text "Download failed..."
                
                $downloadComplete = $false
            
                if ($retryCount -lt $MaxRetries) {
                    Write-Text "Retrying..."
                    Start-Sleep -Seconds $Interval
                } else {
                    Write-Text -Type "error" -Text "Maximum retries reached. Download failed." -LineBefore
                }
            } finally {
                # cleanup
                if ($reader) { $reader.Close() }
                if ($writer) { $writer.Flush(); $writer.Close() }
        
                $ErrorActionPreference = $storeEAP
                [GC]::Collect()
            } 
        }   
    }
}

Invoke-Script "Get-Command"