
function Install-IsrNinja {
    try {
        Write-Welcome -Title "Install NinjaOne" -Description "Install NinjaOne for Nuvia ISR's" -Command "intech install isr ninja"
        Write-Text -Type "header" -Text "Install NinjaOne" -LineBefore -LineAfter

        Add-TempFolder
        Invoke-Installation

        Write-Exit
    } catch {
        Write-Text "Install error: $($_.Exception.Message)" -Type "error"
    }
}

function Add-TempFolder {
    try {
        Write-Text "Creating TEMP folder..."
        Write-Text "Path: C:\Users\$env:username\Desktop\"

        if (-not (Test-Path -PathType Container "C:\Users\$env:username\Desktop\TEMP")) {
            New-Item -Path "C:\Users\$env:username\Desktop\" -Name "TEMP" -ItemType Directory | Out-Null
        }
        
        Write-Text -Type "done" -Text "Folder created." -LineAfter
    } catch {
        Write-Text "Error creating temp folder: $($_.Exception.Message)" -Type "error"
    }
}

function Invoke-Installation {
    $url = "https://app.ninjarmm.com/agent/installer/0274c0c3-3ec8-44fc-93cb-79e96f191e07/nuviaisrcenteroremut-5.7.8836-windows-installer.msi"
    $paths = @("C:\Program Files\NinjaRemote")
    $appName = "NinjaOne"
    $installed = Find-ExistingInstall -Paths $paths -App $appName
    if (!$installed) { Install-Program -Url $url -AppName $appName -Args "/qn" }
}

function Find-ExistingInstall {
    param (
        [parameter(Mandatory = $true)]
        [array]$Paths,
        [parameter(Mandatory = $true)]
        [string]$App
    )

    Write-Text "Checking for existing install..."

    $installationFound = $false
    $service = Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue

    if ($null -ne $service -and $service.Status -eq "Running") {
        $installationFound = $true
    }

    if ($installationFound) { Write-Text -Type "success" -Text "$App already installed." -LineAfter } 
    else { Write-Text "$App not found."  -LineAfter }

    return $installationFound
}

function Install-Program {
    param (
        [parameter(Mandatory = $true)]
        [string]$Url,
        [parameter(Mandatory = $true)]
        [string]$AppName,
        [parameter(Mandatory = $false)]
        [string]$Args = ""
    )

    try {
        $tempPath = "C:\Users\$env:username\Desktop\TEMP"
        $download = Get-Download -Url $Url -Target "$tempPath\$AppName.msi"

        if ($download) {
            Write-Text -Text "Intalling..." -LineBefore

            Start-Process -FilePath "msiexec" -ArgumentList "/i ``"$tempPath\$AppName.msi``" $Args" -Wait

            $service = Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue

            if ($null -ne $service -and $service.Status -eq "Running") {
                Write-Text -Type "success" -Text "$AppName successfully installed." -LineAfter
            } else {
                Write-Text -Type "error" -Text "$AppName did not successfully install." -LineAfter
            }
        } else {
            Write-Text "Download failed. Skipping." -Type "error" -LineAfter
        }
    } catch {
        Write-Text -Type "error" -Text "Installation Error: $($_.Exception.Message)"
        Write-Exit -Script "Install-NinjaOne"
    }
}