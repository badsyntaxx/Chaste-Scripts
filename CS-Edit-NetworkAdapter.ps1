if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$($PWD.Path)'; & '$PSCommandPath';`";`"$args`"";
    Exit;
} 

$Script = "Edit-NetworkAdapter"
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
$path = if ($isAdmin) { "$env:SystemRoot\Temp" } else { "$env:TEMP" }

if (Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -ErrorAction SilentlyContinue) {
    $framework = Get-Content -Path "$PSScriptRoot\CS-Framework.ps1" -Raw
    Write-Host "   Using local file."
    Start-Sleep 1
} else {
    $framework = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/badsyntaxx/Chaste-Scripts/main/CS-Framework.ps1"
}

$core = @"
function Edit-NetworkAdapter {
    Write-Text -Type "header" -Text "Get started"

    `$options = @(
        "Display adapters        - Display all non hidden network adapters."
        "Select network adapter  - Select the network adapter you want to edit."
        "Quit                    - Do nothing and exit."
    )

    `$choice = Get-Option -Options `$options
    Write-Host 
    if (0 -eq `$choice) { Show-Adapters }
    if (1 -eq `$choice) { Select-Adapter }
    if (3 -eq `$choice) { Exit }
}

function Select-Adapter {
    Write-Text -Type "header" -Text "Select an adapter"

    `$adapters = @()
    foreach (`$n in (Get-NetAdapter | Select-Object -ExpandProperty Name)) {
        `$adapters += `$n
    }

    `$choice = Get-Option -Options `$adapters

    `$netAdapter = Get-NetAdapter -Name `$adapters[`$choice]
    `$adapterIndex = `$netAdapter.InterfaceIndex
    `$ipData = Get-NetIPAddress -InterfaceIndex `$adapterIndex -AddressFamily IPv4 | Where-Object { `$_.PrefixOrigin -ne "WellKnown" -and `$_.SuffixOrigin -ne "Link" -and (`$_.AddressState -eq "Preferred" -or `$_.AddressState -eq "Tentative") } | Select-Object -First 1
    `$interface = Get-NetIPInterface -InterfaceIndex `$adapterIndex

    `$script:ipv4Regex = "^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){0,4}$"

    `$adapter = [ordered]@{
        "name"    = `$adapters[`$choice]
        "self"    = Get-NetAdapter -Name `$adapters[`$choice]
        "index"   = `$netAdapter.InterfaceIndex
        "ip"      = `$ipData.IPAddress
        "gateway" = Get-NetIPConfiguration -InterfaceAlias `$adapters[`$choice] | ForEach-Object { `$_.IPv4DefaultGateway.NextHop }
        "subnet"  = Convert-CIDRToMask -CIDR `$ipData.PrefixLength
        "dns"     = Get-DnsClientServerAddress -InterfaceIndex `$adapterIndex | Select-Object -ExpandProperty ServerAddresses
        "IPDHCP"  = if (`$interface.Dhcp -eq "Enabled") { `$true } else { `$false }
    }

    Get-DesiredNetAdapterSettings -Adapter `$adapter
}

function Get-DesiredNetAdapterSettings {
    param (
        [parameter(Mandatory = `$true)]
        [System.Collections.Specialized.OrderedDictionary]`$Adapter
    )

    Write-Text -Type "header" -Text "Edit net adapter" -LineBefore
    Get-AdapterInfo -AdapterName `$Adapter["name"]

    `$memoryStream = New-Object System.IO.MemoryStream
    `$binaryFormatter = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
    `$binaryFormatter.Serialize(`$memoryStream, `$Adapter)
    `$memoryStream.Position = 0
    `$Original = `$binaryFormatter.Deserialize(`$memoryStream)
    `$memoryStream.Close()

    `$Adapter = Get-IPSettings -Adapter `$Adapter
    `$Adapter = Get-DNSSettings -Adapter `$Adapter

    Confirm-Edits -Adapter `$Adapter -Original `$Original
}

function Get-IPSettings {
    param (
        [parameter(Mandatory = `$true)]
        [System.Collections.Specialized.OrderedDictionary]`$Adapter
    )

    `$options = @(
        "Static IP addressing  - Set this adapter to static and enter IP data manually."
        "DHCP IP addressing    - Set this adapter to DHCP."
        "Back                  - Go back to network adapter selection."
    )

    `$choice = Get-Option -Options `$options

    `$desiredSettings = `$Adapter

    if (`$choice -eq 0) { 
        Write-Text "-"
        `$ip = Get-Input -Prompt "IPv4 Address" -Validate `$ipv4Regex -Value `$Adapter["ip"]
        `$subnet = Get-Input -Prompt "Subnet Mask" -Validate `$ipv4Regex -Value `$Adapter["subnet"]       
        `$gateway = Get-Input -Prompt "Gateway" -Validate `$ipv4Regex -Value `$Adapter["gateway"]
        
        if (`$ip -eq "") { `$ip = `$Adapter["ip"] }
        if (`$subnet -eq "") { `$subnet = `$Adapter["subnet"] }
        if (`$gateway -eq "") { `$gateway = `$Adapter["gateway"] }

        `$desiredSettings["ip"] = `$ip
        `$desiredSettings["subnet"] = `$subnet
        `$desiredSettings["gateway"] = `$gateway
        `$desiredSettings["IPDHCP"] = `$false
    }

    if (1 -eq `$choice) { `$desiredSettings["IPDHCP"] = `$true }
    if (2 -eq `$choice) { Get-DesiredNetAdapterSettings }

    return `$desiredSettings
}

function Get-DNSSettings {
    param (
        [parameter(Mandatory = `$true)]
        [System.Collections.Specialized.OrderedDictionary]`$Adapter
    )

    try {
        Write-Text "-"

        `$options = @(
            "Static DNS addressing  - Set this adapter to static and enter DNS data manually."
            "DHCP DNS addressing    - Set this adapter to DHCP."
            "Back                   - Go back to network adapter selection."
        )

        `$choice = Get-Option -Options `$options

        Write-Text "-"

        `$dns = @()

        if (`$choice -eq 0) { 
            `$prompt = Get-Input -Prompt "Enter a DNS (Leave blank to skip)" -Validate `$ipv4Regex
            `$dns += `$prompt
            while (`$prompt.Length -gt 0) {
                `$prompt = Get-Input -Prompt "Enter another DNS (Leave blank to skip)" -Validate `$ipv4Regex
                if (`$prompt -ne "") { `$dns += `$prompt }
            }
            `$Adapter["dns"] = `$dns
        }
        if (1 -eq `$choice) { `$Adapter["DNSDHCP"] = `$true }
        if (2 -eq `$choice) { Get-DNSSettings }

        return `$Adapter
    } catch {
        Write-Text -Type "error" -Text "Get DNS Error: `$(`$_.Exception)"
        Read-Host "   Press any key to continue"
    }
}

function Confirm-Edits {
    param (
        [parameter(Mandatory = `$true)]
        [System.Collections.Specialized.OrderedDictionary]`$Adapter,
        [parameter(Mandatory = `$true)]
        [System.Collections.Specialized.OrderedDictionary]`$Original
    )

    try {
        Write-Text -Type "header" -Text "Confirm edits" -LineBefore

        `$status = Get-NetAdapter -Name `$Adapter["name"] | Select-Object -ExpandProperty Status
        if (`$status -eq "Up") {
            Write-Host " `$([char]0x2022)" -ForegroundColor "Green" -NoNewline
            Write-Host " `$(`$Original["name"])" -ForegroundColor "DarkGray"
        } else {
            Write-Host " `$([char]0x25BC)" -ForegroundColor "Red" -NoNewline
            Write-Host " `$(`$Original["name"])" -ForegroundColor "DarkGray"
        }

        if (`$Adapter["IPDHCP"]) {
            Write-Text -Type "compare" -OldData "IPv4 Address. . . : `$(`$Original["ip"])" -NewData "Dynamic"
            Write-Text -Type "compare" -OldData "Subnet Mask . . . : `$(`$Original["subnet"])" -NewData "Dynamic"
            Write-Text -Type "compare" -OldData "Default Gateway . : `$(`$Original["gateway"])" -NewData "Dynamic"
        } else {
            Write-Text -Type "compare" -OldData "IPv4 Address. . . : `$(`$Original["ip"])" -NewData `$(`$Adapter['ip'])
            Write-Text -Type "compare" -OldData "Subnet Mask . . . : `$(`$Original["subnet"])" -NewData `$(`$Adapter['subnet'])
            Write-Text -Type "compare" -OldData "Default Gateway . : `$(`$Original["gateway"])" -NewData `$(`$Adapter['gateway'])
        }

        `$originalDNS = `$Original["dns"]
        `$newDNS = `$Adapter["dns"]
        `$count = 0
        if (`$originalDNS.Count -gt `$newDNS.Count) {
            `$count = `$originalDNS.Count
        } else {
            `$count = `$newDNS.Count
        }
    
        if (`$Adapter["DNSDHCP"]) {
            for (`$i = 0; `$i -lt `$count; `$i++) {
                if (`$i -eq 0) {
                    Write-Text -Type "compare" -OldData "DNS Servers . . . : `$(`$originalDNS[`$i])" -NewData "Dynamic"
                } else {
                    Write-Text -Type "compare" -OldData "                    `$(`$originalDNS[`$i])" -NewData "Dynamic"
                }
            }
        } else {
            for (`$i = 0; `$i -lt `$count; `$i++) {
                if (`$i -eq 0) {
                    Write-Text -Type "compare" -OldData "DNS Servers . . . : `$(`$originalDNS[`$i])" -NewData `$(`$newDNS[`$i])
                } else {
                    Write-Text -Type "compare" -OldData "                    `$(`$originalDNS[`$i])" -NewData `$(`$newDNS[`$i])
                }
            }
        }
        
        Write-Host

        `$options = @(
            "Submit  - Confirm and apply changes", 
            "Reset   - Start over.", 
            "Exit    - Do nothing and exit."
        )

        `$choice = Get-Option -Options `$options

        if (`$choice -ne 0 -and `$choice -ne 2) { Invoke-Script "Edit-NetworkAdapter" }
        if (`$choice -eq 2) { Write-Exit -Script "Edit-NetworkAdapter" }

        `$dnsString = ""
    
        `$dns = `$Adapter['dns']

        if (`$dns.Count -gt 0) { `$dnsString = `$dns -join ", " } 
        else { `$dnsString = `$dns[0] }

        Get-NetAdapter -Name `$adapter["name"] | Remove-NetIPAddress -Confirm:`$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias `$adapter["name"] -DestinationPrefix 0.0.0.0/0 -Confirm:`$false -ErrorAction SilentlyContinue

        if (`$Adapter["IPDHCP"]) {
            Write-Text "Enabling DHCP for IPv4." -LineBefore
            Set-NetIPInterface -InterfaceIndex `$adapterIndex -Dhcp Enabled  | Out-Null
            netsh interface ipv4 set address name="`$(`$adapter["name"])" source=dhcp | Out-Null
            Write-Text -Type "done" -Text "The network adapters IP settings were set to dynamic"
        } else {
            Write-Text "Disabling DHCP and applying static addresses." -LineBefore
            netsh interface ipv4 set address name="`$(`$adapter["name"])" static `$Adapter["ip"] `$Adapter["subnet"] `$Adapter["gateway"] | Out-Null
            Write-Text -Type "done" -Text "The network adapters IP, subnet, and gateway were set to static and your addresses were applied."
        }

        if (`$Adapter["DNSDHCP"]) {
            Write-Text "Enabling DHCP for DNS."
            Set-DnsClientServerAddress -InterfaceAlias `$Adapter["name"] -ResetServerAddresses | Out-Null
            Write-Text -Type "done" -Text "The network adapters DNS settings were set to dynamic"
        } else {
            Write-Text "Disabling DHCP and applying static addresses."
            Set-DnsClientServerAddress -InterfaceAlias `$Adapter["name"] -ServerAddresses `$dnsString
            Write-Text -Type "done" -Text "The network adapters DNS was set to static and your addresses were applied."
        }

        Disable-NetAdapter -Name `$Adapter["name"] -Confirm:`$false
        Start-Sleep 1
        Enable-NetAdapter -Name `$Adapter["name"] -Confirm:`$false

        Write-Exit -Message "Your settings have been applied." -Script "Edit-NetworkAdapter"
    } catch {
        Write-Text -Type "error" -Text "Confirm Error: `$(`$_.Exception)"
        Read-Host "   Press any key to continue"
    }
}

function Get-AdapterInfo {
    param (
        [parameter(Mandatory = `$false)]
        [string]`$AdapterName
    )

    `$macAddress = Get-NetAdapter -Name `$AdapterName | Select-Object -ExpandProperty MacAddress
    `$name = Get-NetAdapter -Name `$AdapterName | Select-Object -ExpandProperty Name
    `$status = Get-NetAdapter -Name `$AdapterName | Select-Object -ExpandProperty Status
    `$index = Get-NetAdapter -Name `$AdapterName | Select-Object -ExpandProperty InterfaceIndex
    `$gateway = Get-NetIPConfiguration -InterfaceAlias `$adapterName | ForEach-Object { `$_.IPv4DefaultGateway.NextHop }
    `$interface = Get-NetIPInterface -InterfaceIndex `$index
    `$dhcp = `$(if (`$interface.Dhcp -eq "Enabled") { "DHCP" } else { "Static" })
    `$ipData = Get-NetIPAddress -InterfaceIndex `$index -AddressFamily IPv4 | Where-Object { `$_.PrefixOrigin -ne "WellKnown" -and `$_.SuffixOrigin -ne "Link" -and (`$_.AddressState -eq "Preferred" -or `$_.AddressState -eq "Tentative") } | Select-Object -First 1
    `$ipAddress = `$ipData.IPAddress
    `$subnet = Convert-CIDRToMask -CIDR `$ipData.PrefixLength
    `$dnsServers = Get-DnsClientServerAddress -InterfaceIndex `$index | Select-Object -ExpandProperty ServerAddresses

    if (`$status -eq "Up") {
        Write-Host " `$([char]0x2022)" -ForegroundColor "Green" -NoNewline
        Write-Host " `$name(`$dhcp)" 
    } else {
        Write-Host " `$([char]0x25BC)" -ForegroundColor "Red" -NoNewline
        Write-Host " `$name(`$dhcp)"
    }

    Write-Text "MAC Address . . . : `$macAddress"
    Write-Text "IPv4 Address. . . : `$ipAddress"
    Write-Text "Subnet Mask . . . : `$subnet"
    Write-Text "Default Gateway . : `$gateway"

    for (`$i = 0; `$i -lt `$dnsServers.Count; `$i++) {
        if (`$i -eq 0) {
            Write-Text "DNS Servers . . . : `$(`$dnsServers[`$i])"
        } else {
            Write-Text "                    `$(`$dnsServers[`$i])"
        }
    }
    Write-Host
}

function Convert-CIDRToMask {
    param (
        [parameter(Mandatory = `$false)]
        [int]`$CIDR
    )

    switch (`$CIDR) {
        8 { `$mask = "255.0.0.0" }
        9 { `$mask = "255.128.0.0" }
        10 { `$mask = "255.192.0.0" }
        11 { `$mask = "255.224.0.0" }
        12 { `$mask = "255.240.0.0" }
        13 { `$mask = "255.248.0.0" }
        14 { `$mask = "255.252.0.0" }
        15 { `$mask = "255.254.0.0" }
        16 { `$mask = "255.255.0.0" }
        17 { `$mask = "255.255.128.0" }
        18 { `$mask = "255.255.192.0" }
        19 { `$mask = "255.255.224.0" }
        20 { `$mask = "255.255.240.0" }
        21 { `$mask = "255.255.248.0" }
        22 { `$mask = "255.255.252.0" }
        23 { `$mask = "255.255.254.0" }
        24 { `$mask = "255.255.255.0" }
        25 { `$mask = "255.255.255.128" }
        26 { `$mask = "255.255.255.192" }
        27 { `$mask = "255.255.255.224" }
        28 { `$mask = "255.255.255.240" }
        29 { `$mask = "255.255.255.248" }
        30 { `$mask = "255.255.255.252" }
        31 { `$mask = "255.255.255.254" }
        32 { `$mask = "255.255.255.255" }
    }

    return `$mask
}

function Show-Adapters {
    param (
        [parameter(Mandatory = `$false)]
        [switch]`$Detailed
    )

    Clear-Host

    `$adapters = @()
    foreach (`$n in (Get-NetAdapter | Select-Object -ExpandProperty Name)) {
        `$adapters += `$n
    }

    foreach (`$a in `$adapters) {
        Get-AdapterInfo -AdapterName `$a
    }

    Edit-NetworkAdapter
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -NoExit -File "$path\$Script.ps1" -Verb RunAs