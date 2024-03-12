function Edit-NetworkAdapter {
    Write-Text -Type "header" -Text "Get started"

    $options = @(
        "Display adapters        - Display all non hidden network adapters."
        "Select network adapter  - Select the network adapter you want to edit."
        "Quick import            - Import IP settings directly to an adapter using .txt file."
        "Quit                    - Do nothing and exit."
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

    $netAdapter = Get-NetAdapter -Name $adapters[$choice]
    $adapterIndex = $netAdapter.InterfaceIndex
    $ipData = Get-NetIPAddress -InterfaceIndex $adapterIndex -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -ne "WellKnown" -and $_.SuffixOrigin -ne "Link" -and ($_.AddressState -eq "Preferred" -or $_.AddressState -eq "Tentative") } | Select-Object -First 1
    $interface = Get-NetIPInterface -InterfaceIndex $adapterIndex

    $script:ipv4Regex = "^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){0,4}$"

    $adapter = [ordered]@{
        "name"    = $adapters[$choice]
        "self"    = Get-NetAdapter -Name $adapters[$choice]
        "index"   = $netAdapter.InterfaceIndex
        "ip"      = $ipData.IPAddress
        "gateway" = Get-NetIPConfiguration -InterfaceAlias $adapters[$choice] | ForEach-Object { $_.IPv4DefaultGateway.NextHop }
        "subnet"  = Convert-CIDRToMask -CIDR $ipData.PrefixLength
        "dns"     = Get-DnsClientServerAddress -InterfaceIndex $adapterIndex | Select-Object -ExpandProperty ServerAddresses
        "IPDHCP"  = if ($interface.Dhcp -eq "Enabled") { $true } else { $false }
    }

    Get-DesiredNetAdapterSettings -Adapter $adapter
}

function Get-DesiredNetAdapterSettings {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Adapter
    )

    Write-Text -Type "header" -Text "Edit net adapter" -LineBefore
    Get-AdapterInfo -AdapterName $Adapter["name"]

    $memoryStream = New-Object System.IO.MemoryStream
    $binaryFormatter = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
    $binaryFormatter.Serialize($memoryStream, $Adapter)
    $memoryStream.Position = 0
    $Original = $binaryFormatter.Deserialize($memoryStream)
    $memoryStream.Close()

    $Adapter = Get-IPSettings -Adapter $Adapter
    $Adapter = Get-DNSSettings -Adapter $Adapter

    Confirm-Edits -Adapter $Adapter -Original $Original
}

function Get-IPSettings {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Adapter
    )

    $options = @(
        "Static IP addressing  - Set this adapter to static and enter IP data manually."
        "DHCP IP addressing    - Set this adapter to DHCP."
        "Back                  - Go back to network adapter selection."
    )

    $choice = Get-Option -Options $options

    $desiredSettings = $Adapter

    if ($choice -eq 0) { 
        Write-Text "-"
        $ip = Get-Input -Prompt "IPv4 Address" -Validate $ipv4Regex -Value $Adapter["ip"]
        $subnet = Get-Input -Prompt "Subnet Mask" -Validate $ipv4Regex -Value $Adapter["subnet"]       
        $gateway = Get-Input -Prompt "Gateway" -Validate $ipv4Regex -Value $Adapter["gateway"]
        
        if ($ip -eq "") { $ip = $Adapter["ip"] }
        if ($subnet -eq "") { $subnet = $Adapter["subnet"] }
        if ($gateway -eq "") { $gateway = $Adapter["gateway"] }

        $desiredSettings["ip"] = $ip
        $desiredSettings["subnet"] = $subnet
        $desiredSettings["gateway"] = $gateway
        $desiredSettings["IPDHCP"] = $false
    }

    if (1 -eq $choice) { $desiredSettings["IPDHCP"] = $true }
    if (2 -eq $choice) { Get-DesiredNetAdapterSettings }

    return $desiredSettings
}

function Get-DNSSettings {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Adapter
    )

    try {
        Write-Text "-"

        $options = @(
            "Static DNS addressing  - Set this adapter to static and enter DNS data manually."
            "DHCP DNS addressing    - Set this adapter to DHCP."
            "Back                   - Go back to network adapter selection."
        )

        $choice = Get-Option -Options $options

        Write-Text "-"

        $dns = @()

        if ($choice -eq 0) { 
            $prompt = Get-Input -Prompt "Enter a DNS (Leave blank to skip)" -Validate $ipv4Regex
            $dns += $prompt
            while ($prompt.Length -gt 0) {
                $prompt = Get-Input -Prompt "Enter another DNS (Leave blank to skip)" -Validate $ipv4Regex
                if ($prompt -ne "") { $dns += $prompt }
            }
            $Adapter["dns"] = $dns
        }
        if (1 -eq $choice) { $Adapter["DNSDHCP"] = $true }
        if (2 -eq $choice) { Get-DNSSettings }

        return $Adapter
    } catch {
        Write-Text -Type "error" -Text "Get DNS Error: $($_.Exception)"
        Read-Host "   Press any key to continue"
    }
}

function Confirm-Edits {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Adapter,
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Original
    )

    try {
        Write-Text -Type "header" -Text "Confirm edits" -LineBefore

        if ($status -eq "Up") {
            Write-Host " $([char]0x2022)" -ForegroundColor "Green" -NoNewline
            Write-Host " $($Original["name"])" 
        } else {
            Write-Host " $([char]0x25BC)" -ForegroundColor "Red" -NoNewline
            Write-Host " $($Original["name"])"
        }
    
        Write-Text "MAC Address . . . : $($Original["mac"])"
        Write-Text "IPv4 Address. . . : $($Original["ip"]) $([char]0x2192) $($Adapter['ip'])"
        Write-Text "Subnet Mask . . . : $($Original["subnet"]) $([char]0x2192) $($Adapter['subnet'])"
        Write-Text "Default Gateway . : $($Original["gateway"]) $([char]0x2192) $($Adapter['gateway'])"

        $dnsServers = $Original["dns"]
    
        for ($i = 0; $i -lt $dnsServers.Count; $i++) {
            if ($i -eq 0) {
                Write-Text "DNS Servers . . . : $($dnsServers[$i])"
            } else {
                Write-Text "                    $($dnsServers[$i])"
            }
        }
        
        Write-Host

        $options = @(
            "Submit  - Confirm and apply changes", 
            "Reset   - Start over.", 
            "Exit    - Do nothing and exit."
        )

        $choice = Get-Option -Options $options

        if ($choice -ne 0 -and $choice -ne 2) { Invoke-Script "Edit-NetworkAdapter" }
        if ($choice -eq 2) { Write-CloseOut -Script "Edit-NetworkAdapter" }

        $dnsString = ""
    
        $dns = $Adapter['dns']

        if ($dns.Count -gt 0) { $dnsString = $dns -join "," } 
        else { $dnsString = $dns[0] }

        Get-NetAdapter -Name $adapter["name"] | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias $adapter["name"] -DestinationPrefix 0.0.0.0/0 -Confirm:$false -ErrorAction SilentlyContinue

        if ($Adapter["IPDHCP"]) {
            Write-Text "Enabling DHCP for IPv4." -LineBefore
            Set-NetIPInterface -InterfaceIndex $adapterIndex -Dhcp Enabled  | Out-Null
            netsh interface ipv4 set address name="$($adapter["name"])" source=dhcp | Out-Null
            Write-Text -Type "done" -Text "The network adapters IP settings were set to dynamic"
        } else {
            Write-Text "Disabling DHCP and applying static addresses." -LineBefore
            netsh interface ipv4 set address name="$($adapter["name"])" static $Adapter["ip"] $Adapter["subnet"] $Adapter["gateway"] | Out-Null
            Write-Text -Type "done" -Text "The network adapters IP, subnet, and gateway were set to static and your addresses were applied."
        }

        if ($Adapter["DNSDHCP"]) {
            Write-Text "Enabling DHCP for DNS."
            Set-DnsClientServerAddress -InterfaceAlias $Adapter["name"] -ResetServerAddresses | Out-Null
            Write-Text -Type "done" -Text "The network adapters DNS settings were set to dynamic"
        } else {
            Write-Text "Disabling DHCP and applying static addresses."
            Set-DnsClientServerAddress -InterfaceAlias $Adapter["name"] -ServerAddresses $dnsString
            Write-Text -Type "done" -Text "The network adapters DNS was set to static and your addresses were applied."
        }

        Disable-NetAdapter -Name $Adapter["name"] -Confirm:$false
        Enable-NetAdapter -Name $Adapter["name"] -Confirm:$false

        Write-CloseOut -Message "Your settings have been applied." -Script "Edit-NetworkAdapter"
    } catch {
        Write-Text -Type "error" -Text "Confirm Error: $($_.Exception)"
        Read-Host "   Press any key to continue"
    }
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
    $gateway = Get-NetIPConfiguration -InterfaceAlias $adapterName | ForEach-Object { $_.IPv4DefaultGateway.NextHop }
    $interface = Get-NetIPInterface -InterfaceIndex $index
    $dhcp = $(if ($interface.Dhcp -eq "Enabled") { "DHCP" } else { "Static" })
    $ipData = Get-NetIPAddress -InterfaceIndex $index -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -ne "WellKnown" -and $_.SuffixOrigin -ne "Link" -and ($_.AddressState -eq "Preferred" -or $_.AddressState -eq "Tentative") } | Select-Object -First 1
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

    return $mask
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
        return $pos
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

    if ($Message -ne "") { Write-Text -Type "success" -Text $Message }
    $paths = @("$env:TEMP\$Script.ps1", "$env:SystemRoot\Temp\$Script.ps1")
    foreach ($p in $paths) { Get-Item -ErrorAction SilentlyContinue $p | Remove-Item -ErrorAction SilentlyContinue }
    $param = Read-Host -Prompt "`r`n   Type a command or just hit enter to exit"
    Write-Host
    if ($param.Length -gt 0) {
        Invoke-RestMethod "chaste.dev/$param" | Invoke-Expression -ErrorAction SilentlyContinue
    }
}

function Get-Download {
    param (
        [parameter(Mandatory = $false)]
        [string]$Uri,
        [parameter(Mandatory = $false)]
        [string]$Target,
        [parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        [parameter(Mandatory = $false)]
        [int]$Interval = 3
    )

    $downloadComplete = $true 
    Write-Text -Text "Downloading..."
    
    for ($retryCount = 1; $retryCount -le $MaxRetries; $retryCount++) {
        try {
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($Uri, $Target)
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

    if ($downloadComplete) {
        Write-Text -Type "done" -Text "Download complete."
        return $true
    } else {
        Get-Item -ErrorAction SilentlyContinue $Target | Remove-Item -ErrorAction SilentlyContinue 
        return $false
    }
}

Invoke-Script "Edit-NetworkAdapter"