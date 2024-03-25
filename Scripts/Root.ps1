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
        Write-Host
        Write-Host " Chaste Scripts: Root"
        Write-Host " Enter `"" -ForegroundColor DarkGray -NoNewLine
        Write-Host "menu" -ForegroundColor Cyan -NoNewLine
        Write-Host "`" or `"" -ForegroundColor DarkGray -NoNewLine
        Write-Host "help" -ForegroundColor Cyan -NoNewLine
        Write-Host "`" if you don't know commands." -ForegroundColor DarkGray
        Write-Host
        Invoke-Expression $ScriptName
    } catch {
        Write-Host "Initialization Error: $($_.Exception.Message)" -ForegroundColor Red
        Get-Command
    }
}

function Get-Command {
    try {
        Write-Host "  $([char]0x203A) " -NoNewline 

        $command = Read-Host 
        $makeTitleCase = (Get-Culture).TextInfo.ToTitleCase($command)
        $addDash = $makeTitleCase -split '\s+', 2, "RegexMatch" -join '-'
        $fileFunc = $addDash -replace ' ', ''

        if ($command -eq 'help') {
            Write-Host
            Write-Host "    enable admin    - Toggle the built-in administrator account."
            Write-Host "    add user        - Add a user to the system."
            Write-Host "    add local user  - Add a local user to the system."
            Write-Host "    add ad user     - Add a domain user to the system."
            Write-Host
            Get-Command
        } else {
            New-Item -Path "$env:TEMP\Chaste-Script.ps1" -ItemType File -Force | Out-Null

            $url = "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main"
            $dependencies = @("$fileFunc", "Global", "Get-Input", "Get-Option", "Get-UserData", "Get-Download", "Select-User")
            $subPath = "Framework"

            foreach ($dependency in $dependencies) {
                if ($dependency -eq $fileFunc) { $subPath = "Scripts" } else { $subPath = "Framework" }
                if ($dependency -eq 'Reclaim') { $subPath = "Plugins" }
                if ($makeTitleCase -match "(^\w+)") { $firstWord = $matches[1] }
                if ($firstWord -eq 'Intech' -and $dependency -eq $fileFunc) { $subPath = "InTech" }

                $download = Get-Script -Url "$url/$subPath/$dependency.ps1" -Target "$env:TEMP\$dependency.ps1" -ProgressText $dependency
                if (!$download) { throw "Could not acquire dependency." }

                $rawScript = Get-Content -Path "$env:TEMP\$dependency.ps1" -Raw -ErrorAction SilentlyContinue

                Add-Content -Path "$env:TEMP\Chaste-Script.ps1" -Value $rawScript
                Get-Item -ErrorAction SilentlyContinue "$env:TEMP\$dependency.ps1" | Remove-Item -ErrorAction SilentlyContinue

                if ($subPath -eq 'Plugins') { break }
            }

            if ($subPath -ne 'Plugins') { Add-Content -Path "$env:TEMP\Chaste-Script.ps1" -Value "Invoke-Script '$fileFunc'" }

            $chasteScript = Get-Content -Path "$env:TEMP\Chaste-Script.ps1" -Raw
            Invoke-Expression "$chasteScript"
        }
    } catch {
        Write-Host "    Unknown command: $($_.Exception.Message)" -ForegroundColor Red
        Get-Command
    }
}

function Get-Script {
    param (
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$Target,
        [Parameter(Mandatory)]
        [string]$ProgressText
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
            
            $percent = $CurrentValue / $TotalValue
            $percentComplete = $percent * 100
            if ($ValueSuffix) {
                $ValueSuffix = " $ValueSuffix" # add space in front
            }
  
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
        try {
            $storeEAP = $ErrorActionPreference
            $ErrorActionPreference = 'Stop'

            $request = [System.Net.HttpWebRequest]::Create($Url)
            $response = $request.GetResponse()

            if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
                throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$Url'."
            }
            if ($Target -match '^\.\\') { $Target = Join-Path (Get-Location -PSProvider "FileSystem") ($Target -Split '^\.')[1] }
            if ($Target -and !(Split-Path $Target)) { $Target = Join-Path (Get-Location -PSProvider "FileSystem") $Target }
            if ($Target) {
                $fileDirectory = $([System.IO.Path]::GetDirectoryName($Target))
                if (!(Test-Path($fileDirectory))) { [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null }
            }

            [long]$fullSize = $response.ContentLength
            $fullSizeMB = $fullSize / 1024 / 1024
            [byte[]]$buffer = new-object byte[] 1048576
            [long]$total = [long]$count = 0
            $reader = $response.GetResponseStream()
            $writer = new-object System.IO.FileStream $Target, "Create"
            $finalBarCount = 0 #show final bar only one time
            do {
                $count = $reader.Read($buffer, 0, $buffer.Length)
        
                $writer.Write($buffer, 0, $count)
            
                $total += $count
                $totalMB = $total / 1024 / 1024
        
                if ($fullSize -gt 0) {
                    Show-Progress -TotalValue $fullSizeMB -CurrentValue $totalMB -ProgressText $ProgressText -ValueSuffix "MB"
                }

                if ($total -eq $fullSize -and $count -eq 0 -and $finalBarCount -eq 0) {
                    Show-Progress -TotalValue $fullSizeMB -CurrentValue $totalMB -ProgressText $ProgressText -ValueSuffix "MB" -Complete
                    $finalBarCount++
                }
            } while ($count -gt 0)
            Write-Host
            if ($downloadComplete) { return $true } else { return $false }
        } catch {
            # Write-Text -Type "fail" -Text "$($_.Exception.Message)"
        } finally {
            if ($reader) { $reader.Close() }
            if ($writer) { $writer.Flush(); $writer.Close() }
            $ErrorActionPreference = $storeEAP
            [GC]::Collect()
        } 
           
    }
}

Invoke-Script "Get-Command"