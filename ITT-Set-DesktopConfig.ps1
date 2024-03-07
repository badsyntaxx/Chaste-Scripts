
Function Set-DesktopConfig {
    Add-DesktopIcons
    Add-Wallpaper
    Install-BGINfo
    Clear-QuickLaunch
    Clear-Bin
    Set-Desktop
    Read-Host "Press any key to continue"
}

function Initialize-Script {
    param (
        [parameter(Mandatory = $false)]
        [string]$ScriptName
    ) 

    try {
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
            Exit;
        } 

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

Function Add-Wallpaper() {
    New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -PropertyType String -Value 10 -Force
    New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -PropertyType String -Value 0 -Force
     
    Add-Type -TypeDefinition @" 
using System; 
using System.Runtime.InteropServices;
    
public class Params
{ 
    [DllImport("User32.dll",CharSet=CharSet.Unicode)] 
    public static extern int SystemParametersInfo (Int32 uAction, 
                                                    Int32 uParam, 
                                                    String lpvParam, 
                                                    Int32 fuWinIni);
}
"@ 
    
    $SPI_SETDESKWALLPAPER = 0x0014
    $UpdateIniFile = 0x01
    $SendChangeEvent = 0x02
    $fWinIni = $UpdateIniFile -bor $SendChangeEvent
    [Params]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, "C:\Program Files\BGInfo\Nuvia ISR Wallpaper.jpg", $fWinIni)
}

function Install-BGINfo {
    $url = "https://drive.google.com/uc?export=download&id=1vU-AfOmhwdwh7h_Q0IFGXClGQ4AQjjSK"
    $MaxRetries = 3
    $Interval = 3
    for ($retryCount = 1; $retryCount -le $MaxRetries; $retryCount++) {
        try {
            Write-Host "Downloading..."
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($url, "C:\Windows\Temp\BGInfo.zip")
            Write-Host "Download complete."
            break
        } catch {
            Write-Host "   $($_.Exception.Message)`n" -ForegroundColor "Red"
            if ($retryCount -lt $MaxRetries) {
                Write-Host "   Retrying in $Interval seconds"
                Start-Sleep -Seconds $Interval
            } else {
                Write-Host "   Maximum retries reached. Initialization failed." -Color "Red"
            }
        }
    }

    Expand-Archive -LiteralPath "C:\Windows\Temp\BGInfo.zip" -DestinationPath "C:\Windows\Temp\"

    Remove-Item -Path "C:\Windows\Temp\BGInfo.zip" -Recurse
    ROBOCOPY "C:\Windows\Temp\BGInfo" "C:\Program Files\BGInfo" /E
    ROBOCOPY "C:\Windows\Temp\BGInfo" "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" "Start BGInfo.bat"
    Start-Process -FilePath "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\Start BGInfo.bat" -WindowStyle Hidden
    Remove-Item -Path "C:\Windows\Temp\BGInfo" -Recurse
}

Function Clear-QuickLaunch() {
    Remove-Item -Path "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\*" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" -Force -Recurse -ErrorAction SilentlyContinue
    Reset-Explorer
}

Function Add-DesktopIcons() {
    $newStartPanel = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
    $thisPC = "{20D04FE0-3AEA-1069-A2D8-08002B30309D}"
    $recycleBin = "{645FF040-5081-101B-9F08-00AA002F954E}"
    $newExistPC = "Get-ItemProperty -Path $newStartPanel -Name $thisPC"
    $newExistBin = "Get-ItemProperty -Path $newStartPanel -Name $recycleBin"

    if ($newExistPC) {
        Set-ItemProperty -Path $newStartPanel -Name $thisPC -Value 0
    } else {
        New-ItemProperty -Path $newStartPanel -Name $thisPC -Value 0
    }
    if ($newExistBin) {
        Set-ItemProperty -Path $newStartPanel -Name $recycleBin -Value 0
    } else {
        New-ItemProperty -Path $newStartPanel -Name $recycleBin -Value 0
    }
}

Function Clear-Bin() {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}

Function Set-Desktop() {
    ## Specify the sort order parameter: Name, Size, Date Modified
    $sortOrder = "Item Type";

    (New-Object -ComObject shell.application).toggleDesktop();
    Start-Sleep -Milliseconds 1000;

    $WshShell = New-Object -ComObject WScript.Shell;
    Start-Sleep -Milliseconds 1000;

    $WshShell.SendKeys("+{F10}");
    Start-Sleep -Milliseconds 1000;

    $WshShell.SendKeys("o");
    $WshShell.SendKeys($sortOrder.Substring(0, 1));
}

Function Reset-Explorer() {
    Stop-Process -ProcessName explorer -Force
    Start-Process explorer
}

Initialize-Script "Set-DesktopConfig"