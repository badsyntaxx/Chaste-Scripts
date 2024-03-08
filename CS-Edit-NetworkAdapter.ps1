if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
    Exit;
} 

$Script = "Edit-NetworkAdapter"
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
$path = if ($isAdmin) { "$env:SystemRoot\Temp" } else { "$env:TEMP" }
$framework = Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -Raw

if (Get-Content -Path "$PSScriptRoot\CS-Framework.ps1") {
    $framework = Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -Raw
    Write-Host "   Using local file."
    Start-Sleep 1
} else {
    $framework = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1"
}

$core = @"
function Edit-NetworkAdapter {
    Write-Text -Type "header" -Text "Get started"

    $options = @(
        "Display adapters.        - Display all non hidden network adapters."
        "Select network adapter.  - Select the network adapter you want to edit."
        "Quick import             - Import IP settings directly to an adapter using .txt file."
        "Quit                     - Do nothing and exit."
    )

    $choice = Get-Option -Options $options
    Write-Host 
    if (0 -eq $choice) { Show-Adapters }
    if (1 -eq $choice) { Select-Adapter }
    if (2 -eq $choice) { Use-QuickImport }
    if (3 -eq $choice) { Exit }
}

function Select-Adapter {
    Write-Text -Type "header" -Text "Select an adapter"

    $adapters = @()
    foreach ($n in (Get-NetAdapter | Select-Object -ExpandProperty Name)) {
        $adapters += $n
    }

    $choice = Get-Option -Options $adapters

    $script:adapterName = $adapters[$choice]
    $script:netAdapter = Get-NetAdapter -Name $adapterName
    $script:adapterIndex = $netAdapter.InterfaceIndex
    $ipData = Get-NetIPAddress -InterfaceIndex $adapterIndex | Select-Object -First 1
    $script:currentIP = $ipData.IPAddress
    $script:currentGateway = (Get-NetRoute | Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' }).NextHop
    $script:currentSubnet = Convert-CIDRToMask -CIDR $ipData.PrefixLength
    $interface = Get-NetIPInterface -InterfaceIndex $adapterIndex
    $script:currentAssignment = $(if ($interface.Dhcp -eq "Enabled") { "DHCP" } else { "Static" })

    Edit-IP -AdapterName $adapterName
}

function Edit-IP {
    param (
        [parameter(Mandatory = $true)]
        [string]$AdapterName
    )

    Write-Text -Type "header" -Text "Edit net adapter" -LineBefore
    Get-AdapterInfo -AdapterName $AdapterName

    $options = @(
        "Static IP addressing  - Set this adapter to static and enter IP data manually."
        "DHCP IP addressing    - Set this adapter to DHCP."
        "Back                  - Go back to network adapter selection."
    )

    $choice = Get-Option -Options $options

    if (0 -eq $choice) { 
        Write-Host
        $regex = "^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){0,4}$"
        $script:desiredAddress = Get-Input -Prompt "IPv4 Address" -Validate $regex -Value $currentIP
        $script:desiredSubnet = Get-Input -Prompt "Subnet Mask" -Validate $regex -Value $currentSubnet        
        $script:desiredGateway = Get-Input -Prompt "Gateway" -Validate $regex -Value $currentGateway

        if ($desiredAddress -eq "") { $desiredAddress = $currentIP }
        if ($desiredSubnet -eq "") { $desiredSubnet = $currentSubnet }
        if ($desiredGateway -eq "") { $desiredGateway = $currentGateway }
    }

    if (1 -eq $choice) { $script:IPDHCP = $true }
    if (2 -eq $choice) { Select-QuickOrNormal }

    Edit-DNS
}

function Set-IPScheme {
    param (
        [parameter(Mandatory = $true)]
        [boolean]$Automagic,
        [parameter(Mandatory = $false)]
        [string]$Address,
        [parameter(Mandatory = $false)]
        [string]$Subnet,
        [parameter(Mandatory = $false)]
        [string]$Gateway
    )

    Get-NetAdapter -Name $adapterName | Remove-NetIPAddress -Confirm:$false
    Remove-NetRoute -InterfaceAlias $adapterName -DestinationPrefix 0.0.0.0/0 -Confirm:$false

    if ($Automagic) {
        Write-Host "Settings network adapter $adapterName to DHCP"
        Set-NetIPInterface -InterfaceIndex $adapterIndex -Dhcp Enabled
        netsh interface ipv4 set address name="$adapterName" source=dhcp
    } else {
        if ($Address -ne "") { $newAddress = $Address } else { $newAddress = $currentIP }
        if ($Subnet -ne "") { $newSubnet = $Subnet } else { $newSubnet = $currentSubnet }
        if ($Gateway -ne "") { $newGateway = $Gateway } else { $newGateway = $currentGatway }
        netsh interface ipv4 set address name="$adapterName" static $newAddress $newSubnet $newGateway
    }

    Confirm-StartingChoice
}

function Edit-DNS {
    $title = "NETWORK ADAPTER: $adapterName"
    $prompt = "Set to DHCP or set to static and enter the DNS data manually"
    $choices = @(
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Manual", "Set DNS to static and type the DNS data."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&DHCP", "Set the DNS to DHCP."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Back", "Go back to IP entry.")
    )
    $default = 0
    $choice = $host.UI.PromptForChoice($title, $prompt, $choices, $default)
    $script:DNSDHCP = $false

    if (0 -eq $choice) { 
        $script:dns = New-Object System.Collections.Generic.List[System.Object]
        $csl = ""
        $firstLoop = $true
        $prompt = Test-IPIsGood -Prompt "Enter a DNS (Leave blank to skip)"
        $dns.Add($prompt)
        if ("" -ne $dns[0]) {
            $prompt = Test-IPIsGood -Prompt "Enter another DNS (Leave blank to skip)"
            $dns.Add($prompt)
        } else { $skip = $true }
        if ("" -ne $dns[1] -And !$skip) {
            $prompt = Test-IPIsGood -Prompt "Enter another DNS (Leave blank to skip)"
            $dns.Add($prompt)
        } else { $skip = $true }
        if ("" -ne $dns[2] -And !$skip) {
            $prompt = Test-IPIsGood -Prompt "Enter another DNS (Leave blank to skip)"
            $dns.Add($prompt)
        } else { $skip = $true }
        if ("" -ne $dns[3] -And !$skip) {
            $prompt = Test-IPIsGood -Prompt "Enter another DNS (Leave blank to skip)"
            $dns.Add($prompt)
        } else { $skip = $true }
        if ("" -ne $dns[4] -And !$skip) {
            $prompt = Test-IPIsGood -Prompt "Enter another DNS (Leave blank to skip)"
            $dns.Add($prompt)
        } else { $skip = $true }
        if ("" -ne $dns[5] -And !$skip) {
            Write-Host "I'm going to have to stop you here. Really? This many DNS'. You're trippin."
        }

        foreach ($n in $dns) {
            if ($firstLoop) {
                $firstLoop = $false
                $csl = $n
            } else {
                if ("" -ne $n) { $csl += ",$n" } 
            }
        }   
    }
    if (1 -eq $choice) { $script:DNSDHCP = $true }
    if (2 -eq $choice) { Edit-IP }

    Confirm-Edits
}

function Confirm-Edits {
    Write-Host "Here are the IP settings you chose for '$adapterName'"
    Write-Host "IPv4 Address:     $desiredAddress"
    Write-Host "Subnet Mask:      $desiredSubnet"
    Write-Host "Default Gateway:  $desiredGateway"
    $firstLoop = $true
    foreach ($n in $dns) {
        if ($firstLoop) {
            Write-Host "DNS Servers:      $n"
        } else {
            Write-Host "                  $n"
        }
        $firstLoop = $false
    }

    # Set-IPScheme -Automagic $true
    # Set-IPScheme -Automagic $false -Address $address -Subnet $subnet -Gateway $gateway
    # Set-DnsClientServerAddress -ResetServerAddresses
    # $netAdapter | Set-DnsClientServerAddress -ServerAddresses $csl
}

function Get-AdapterInfo {
    param (
        [parameter(Mandatory = $false)]
        [string]$AdapterName
    )

    $macAddress = Get-NetAdapter -Name $AdapterName | Select-Object -ExpandProperty MacAddress
    $name = Get-NetAdapter -Name $AdapterName | Select-Object -ExpandProperty Name
    $status = Get-NetAdapter -Name $AdapterName | Select-Object -ExpandProperty Status
    $index = Get-NetAdapter -Name $AdapterName | Select-Object -ExpandProperty InterfaceIndex
    $gateway = (Get-NetRoute | Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' }).NextHop
    $interface = Get-NetIPInterface -InterfaceIndex $index
    $dhcp = $(if ($interface.Dhcp -eq "Enabled") { "DHCP" } else { "Static" })
    $ipData = Get-NetIPAddress -InterfaceIndex $index | Select-Object -First 1
    $ipAddress = $ipData.IPAddress
    $subnet = Convert-CIDRToMask -CIDR $ipData.PrefixLength
    $dnsServers = Get-DnsClientServerAddress -InterfaceIndex $index | Select-Object -ExpandProperty ServerAddresses

    if ($status -eq "Up") {
        Write-Host " $([char]0x2022)" -ForegroundColor "Green" -NoNewline
        Write-Host " $name($dhcp)" 
    } else {
        Write-Host " $([char]0x25BC)" -ForegroundColor "Red" -NoNewline
        Write-Host " $name($dhcp)"
    }

    Write-Text "MAC Address . . . : $macAddress"
    Write-Text "IPv4 Address. . . : $ipAddress"
    Write-Text "Subnet Mask . . . : $subnet"
    Write-Text "Default Gateway . : $gateway"

    for ($i = 0; $i -lt $dnsServers.Count; $i++) {
        if ($i -eq 0) {
            Write-Text "DNS Servers . . . : $($dnsServers[$i])"
        } else {
            Write-Text "                    $($dnsServers[$i])"
        }
    }
    Write-Host
}

function Convert-CIDRToMask {
    param (
        [parameter(Mandatory = $false)]
        [int]$CIDR
    )

    switch ($CIDR) {
        8 { $mask = "255.0.0.0" }
        9 { $mask = "255.128.0.0" }
        10 { $mask = "255.192.0.0" }
        11 { $mask = "255.224.0.0" }
        12 { $mask = "255.240.0.0" }
        13 { $mask = "255.248.0.0" }
        14 { $mask = "255.252.0.0" }
        15 { $mask = "255.254.0.0" }
        16 { $mask = "255.255.0.0" }
        17 { $mask = "255.255.128.0" }
        18 { $mask = "255.255.192.0" }
        19 { $mask = "255.255.224.0" }
        20 { $mask = "255.255.240.0" }
        21 { $mask = "255.255.248.0" }
        22 { $mask = "255.255.252.0" }
        23 { $mask = "255.255.254.0" }
        24 { $mask = "255.255.255.0" }
        25 { $mask = "255.255.255.128" }
        26 { $mask = "255.255.255.192" }
        27 { $mask = "255.255.255.224" }
        28 { $mask = "255.255.255.240" }
        29 { $mask = "255.255.255.248" }
        30 { $mask = "255.255.255.252" }
        31 { $mask = "255.255.255.254" }
        32 { $mask = "255.255.255.255" }
    }

    $mask
}

function Show-Adapters {
    param (
        [parameter(Mandatory = $false)]
        [switch]$Detailed
    )

    Clear-Host

    $adapters = @()
    foreach ($n in (Get-NetAdapter | Select-Object -ExpandProperty Name)) {
        $adapters += $n
    }

    foreach ($a in $adapters) {
        Get-AdapterInfo -AdapterName $a
    }

    Edit-NetworkAdapter
}

function Use-QuickImport {
    $lines = Get-Content -Path "C:\Users\$env:username\Desktop\ipscheme.txt"
    $ips = ""
    $dns = @()
    $setting = 'ip'
    $ipv4 = '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'

    foreach ($n in $lines) {
        if ($n -notmatch $ipv4) {
            $setting = 'dns'
        } 
        if ($setting -eq 'ip') {
            $ips += $n
        }
        if ($setting -eq 'dns' -And $n -match $ipv4) {
            $dns += $n
        }
        
    }

    Write-Host "These are the IP's"
    Write-Host $ips

    Write-Host "These are the DNS'"
    Write-Host $dns
}

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

        $height = 37
        $width = 110
        $console = $host.UI.RawUI
        $consoleBuffer = $console.BufferSize
        $consoleSize = $console.WindowSize
        $currentWidth = $consoleSize.Width
        $currentHeight = $consoleSize.Height
        if ($consoleBuffer.Width -gt $Width ) { $currentWidth = $Width }
        if ($consoleBuffer.Height -gt $Height ) { $currentHeight = $Height }
        $console.WindowPosition = New-Object System.Management.Automation.Host.Coordinates(0, 0)
        $console.WindowSize = New-Object System.Management.Automation.Host.size($currentWidth, $currentHeight)
        $console.BufferSize = New-Object System.Management.Automation.Host.size($Width, 2000)
        $console.WindowSize = New-Object System.Management.Automation.Host.size($Width, $Height)
        $console.BackgroundColor = "Black"
        $console.ForegroundColor = "Gray"
        $console.WindowTitle = "Chaste Scripts: Edit Network Adapter"
        Clear-Host
        Write-Host "Chaste Scripts: Edit Network Adapter" -ForegroundColor DarkGray
        Write-Host
        Invoke-Expression $ScriptName
    } catch {
        Write-Text -Type "error" -Text "Initialization Error: $($_.Exception.Message)"
        Read-Host "   Press any key to continue"
    }
}

function Get-Input {
    param (
        [parameter(Mandatory = $false)]
        [string]$Value = "",
        [parameter(Mandatory = $true)]
        [string]$Prompt,
        [parameter(Mandatory = $false)]
        [regex]$Validate = $null,
        [parameter(Mandatory = $false)]
        [switch]$IsSecure = $false,
        [parameter(Mandatory = $false)]
        [switch]$CheckExistingUser = $false
    )

    try {
        $originalPosition = $host.UI.RawUI.CursorPosition

        Write-Host "   $Prompt`:" -NoNewline
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

        if ($userInput.Length -eq 0 -and $Value -ne "") {
            $userInput = $Value
        }

        [Console]::SetCursorPosition($originalPosition.X, $originalPosition.Y)
        Write-Host " $([char]0x2713)" -ForegroundColor "Green" -NoNewline
        if ($IsSecure -and ($userInput.Length -eq 0)) {
            Write-Host " $Prompt`:                                                       "
        } else {
            Write-Host " $Prompt`:$userInput                                             "
        }
    
        return $userInput
    } catch {
        Write-Text -Type "error" -Text "Input Error: $($_.Exception.Message)"
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

function Write-CloseOut {
    param (
        [parameter(Mandatory = $false)]
        [string]$Message = "",
        [parameter(Mandatory = $true)]
        [string]$Script = ""
    )

    if ($Message -ne "") { Write-Text -Text $Message -Type "success" }
    $paths = @("$env:TEMP\$Script.ps1", "$env:SystemRoot\Temp\$Script.ps1")
    foreach ($p in $paths) { Get-Item -ErrorAction SilentlyContinue $p | Remove-Item -ErrorAction SilentlyContinue }
    $param = Read-Host -Prompt "`r`n   Type command to run another task or just hit enter to exit"
    Write-Host
    if ($param.Length -gt 0) {
        Invoke-RestMethod "chaste.dev/$param" | Invoke-Expression -ErrorAction SilentlyContinue
    }
}

function Get-Download {
    param (
        [parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$Downloads,
        [parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        [parameter(Mandatory = $false)]
        [int]$Interval = 3
    )

    $downloadComplete = $true 
    Write-Text -Text "Downloading..."
    foreach ($output in $Downloads.Keys) { 
        $url = $Downloads[$output]
        $file = $output
        for ($retryCount = 1; $retryCount -le $MaxRetries; $retryCount++) {
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($url, $file)
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
        foreach ($file in $Downloads.Keys) { 
            Get-Item -ErrorAction SilentlyContinue $file | Remove-Item -ErrorAction SilentlyContinue 
        }
        return $false
    }
}

Invoke-Script "Edit-NetworkAdapter"

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -NoExit -File "$path\$Script.ps1" -Verb RunAs