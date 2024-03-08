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
Function Edit-NetworkAdapter {
    Write-Host "Chaste Scripts: Edit Network Adapter" -ForegroundColor DarkGray
    Write-Text -Type "header" -Text "Get started" -LineBefore

    `$options = @(
        "Display a list of network adapters."
        "Select a network adapter."
        "Quit."
    )

    `$choice = Get-Option -Options `$options
        
    if (0 -eq `$choice) { Show-Adapters }
    if (1 -eq `$choice) { Select-Adapter }
    if (2 -eq `$choice) { Exit }
}

Function Select-Adapter {
    `$adapters = @()

    foreach (`$n in (Get-NetAdapter | Select-Object -ExpandProperty Name)) {
        `$adapters += `$n
    }

    `$choice = Get-Option -Options `$adapters

    `$script:adapterName = `$adapters[`$choice]
    `$script:netAdapter = Get-NetAdapter -Name `$adapterName
    `$script:adapterIndex = `$netAdapter.InterfaceIndex
    `$ipData = Get-NetIPAddress -InterfaceIndex `$adapterIndex | Select-Object -First 1
    `$script:currentIP = `$ipData.IPAddress
    `$script:currentGateway = (Get-NetRoute | Where-Object { `$_.DestinationPrefix -eq '0.0.0.0/0' }).NextHop
    `$script:currentSubnet = Convert-CIDRToMask -CIDR `$ipData.PrefixLength
    `$interface = Get-NetIPInterface -InterfaceIndex `$adapterIndex
    `$script:currentAssignment = `$(if (`$interface.Dhcp -eq "Enabled") { "DHCP" } else { "Static" })

    Select-QuickOrNormal
}

Function Convert-CIDRToMask {
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

    `$mask
}

Function Select-QuickOrNormal {
    Clear-Host
    `$title = "NETWORK ADAPTER: `$adapterName"
    `$prompt = "Would you like to QUICK IMPORT using a text file?"
    `$choices = @(
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Use a (.txt) file to quickly import IP and DNS settings."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Enter the settings yourself."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Back", "Go back to adapter selection.")
    )
    `$default = 0
    `$choice = `$host.UI.PromptForChoice(`$title, `$prompt, `$choices, `$default)

    if (0 -eq `$choice) { Select-QuickImport }
    if (1 -eq `$choice) { Edit-IP }
    if (2 -eq `$choice) { Select-Adapter }
}

Function Show-Adapters {
    param (
        [parameter(Mandatory = `$false)]
        [switch]`$Detailed
    )

    `$adapters = @()
    foreach (`$n in (Get-NetAdapter | Select-Object -ExpandProperty Name)) {
        `$adapters += `$n
    }

    foreach (`$a in `$adapters) {
        `$macAddress = Get-NetAdapter -Name `$a | Select-Object -ExpandProperty MacAddress
        `$name = Get-NetAdapter -Name `$a | Select-Object -ExpandProperty Name
        `$status = Get-NetAdapter -Name `$a | Select-Object -ExpandProperty Status
        `$index = Get-NetAdapter -Name `$a | Select-Object -ExpandProperty InterfaceIndex
        `$gateway = (Get-NetRoute | Where-Object { `$_.DestinationPrefix -eq '0.0.0.0/0' }).NextHop
        `$interface = Get-NetIPInterface -InterfaceIndex `$index
        `$dhcp = `$(if (`$interface.Dhcp -eq "Enabled") { "DHCP" } else { "Static" })
        `$ipData = Get-NetIPAddress -InterfaceIndex `$index | Select-Object -First 1
        `$ipAddress = `$ipData.IPAddress
        `$subnet = Convert-CIDRToMask -CIDR `$ipData.PrefixLength
        `$dnsServers = Get-DnsClientServerAddress -InterfaceIndex `$index | Select-Object -ExpandProperty ServerAddresses

        Write-Text -Type "header" -Text "Adapter:`$name(`$dhcp)" -LineBefore
        Write-Text "Status. . . . . . : `$status"
        Write-Text "Mac Address . . . : `$macAddress"
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
    }

    Select-Adapter
}

Function Edit-IP {
    Clear-Host
    `$title = "NETWORK ADAPTER: `$adapterName"
    `$prompt = "Set to DHCP or set to static and enter IP data manually"
    `$choices = @(
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Manual", "Set the IP's to static and type the IP data."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&DHCP", "Set the adapter to DHCP."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Back", "Go back to quick import selection.")
    )
    `$default = 0
    `$choice = `$host.UI.PromptForChoice(`$title, `$prompt, `$choices, `$default)
    `$script:IPDHCP = `$false

    if (0 -eq `$choice) { 
        `$script:desiredAddress = Test-IPIsGood -Prompt "Enter IP Address (Leave blank to skip)"
        `$script:desiredSubnet = Test-IPIsGood -Prompt "Enter Subnet mask (Leave blank to skip)"        
        `$script:desiredGateway = Test-IPIsGood -Prompt "Enter Gateway (Leave blank to skip)"

        if ("" -eq `$desiredAddress) { `$desiredAddress = `$currentIP }
        if ("" -eq `$desiredSubnet) { `$desiredSubnet = `$currentSubnet }
        if ("" -eq `$desiredGateway) { `$desiredGateway = `$currentGateway }
    }
    if (1 -eq `$choice) { `$script:IPDHCP = `$true }
    if (2 -eq `$choice) { Select-QuickOrNormal }

    Edit-DNS
}

Function Set-IPScheme {
    param (
        [parameter(Mandatory = `$true)]
        [boolean]`$Automagic,
        [parameter(Mandatory = `$false)]
        [string]`$Address,
        [parameter(Mandatory = `$false)]
        [string]`$Subnet,
        [parameter(Mandatory = `$false)]
        [string]`$Gateway
    )

    Get-NetAdapter -Name `$adapterName | Remove-NetIPAddress -Confirm:`$false
    Remove-NetRoute -InterfaceAlias `$adapterName -DestinationPrefix 0.0.0.0/0 -Confirm:`$false

    if (`$Automagic) {
        Write-Host "Settings network adapter `$adapterName to DHCP"
        Set-NetIPInterface -InterfaceIndex `$adapterIndex -Dhcp Enabled
        netsh interface ipv4 set address name="`$adapterName" source=dhcp
    } else {
        if (`$Address -ne "") { `$newAddress = `$Address } else { `$newAddress = `$currentIP }
        if (`$Subnet -ne "") { `$newSubnet = `$Subnet } else { `$newSubnet = `$currentSubnet }
        if (`$Gateway -ne "") { `$newGateway = `$Gateway } else { `$newGateway = `$currentGatway }
        netsh interface ipv4 set address name="`$adapterName" static `$newAddress `$newSubnet `$newGateway
    }

    Confirm-StartingChoice
}

Function Edit-DNS {
    `$title = "NETWORK ADAPTER: `$adapterName"
    `$prompt = "Set to DHCP or set to static and enter the DNS data manually"
    `$choices = @(
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Manual", "Set DNS to static and type the DNS data."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&DHCP", "Set the DNS to DHCP."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Back", "Go back to IP entry.")
    )
    `$default = 0
    `$choice = `$host.UI.PromptForChoice(`$title, `$prompt, `$choices, `$default)
    `$script:DNSDHCP = `$false

    if (0 -eq `$choice) { 
        `$script:dns = New-Object System.Collections.Generic.List[System.Object]
        `$csl = ""
        `$firstLoop = `$true
        `$prompt = Test-IPIsGood -Prompt "Enter a DNS (Leave blank to skip)"
        `$dns.Add(`$prompt)
        if ("" -ne `$dns[0]) {
            `$prompt = Test-IPIsGood -Prompt "Enter another DNS (Leave blank to skip)"
            `$dns.Add(`$prompt)
        } else { `$skip = `$true }
        if ("" -ne `$dns[1] -And !`$skip) {
            `$prompt = Test-IPIsGood -Prompt "Enter another DNS (Leave blank to skip)"
            `$dns.Add(`$prompt)
        } else { `$skip = `$true }
        if ("" -ne `$dns[2] -And !`$skip) {
            `$prompt = Test-IPIsGood -Prompt "Enter another DNS (Leave blank to skip)"
            `$dns.Add(`$prompt)
        } else { `$skip = `$true }
        if ("" -ne `$dns[3] -And !`$skip) {
            `$prompt = Test-IPIsGood -Prompt "Enter another DNS (Leave blank to skip)"
            `$dns.Add(`$prompt)
        } else { `$skip = `$true }
        if ("" -ne `$dns[4] -And !`$skip) {
            `$prompt = Test-IPIsGood -Prompt "Enter another DNS (Leave blank to skip)"
            `$dns.Add(`$prompt)
        } else { `$skip = `$true }
        if ("" -ne `$dns[5] -And !`$skip) {
            Write-Host "I'm going to have to stop you here. Really? This many DNS'. You're trippin."
        }

        foreach (`$n in `$dns) {
            if (`$firstLoop) {
                `$firstLoop = `$false
                `$csl = `$n
            } else {
                if ("" -ne `$n) { `$csl += ",`$n" } 
            }
        }   
    }
    if (1 -eq `$choice) { `$script:DNSDHCP = `$true }
    if (2 -eq `$choice) { Edit-IP }

    Confirm-Edits
}

Function Confirm-Edits {
    Write-Host "Here are the IP settings you chose for '`$adapterName'"
    Write-Host "IPv4 Address:     `$desiredAddress"
    Write-Host "Subnet Mask:      `$desiredSubnet"
    Write-Host "Default Gateway:  `$desiredGateway"
    `$firstLoop = `$true
    foreach (`$n in `$dns) {
        if (`$firstLoop) {
            Write-Host "DNS Servers:      `$n"
        } else {
            Write-Host "                  `$n"
        }
        `$firstLoop = `$false
    }

    # Set-IPScheme -Automagic `$true
    # Set-IPScheme -Automagic `$false -Address `$address -Subnet `$subnet -Gateway `$gateway
    # Set-DnsClientServerAddress -ResetServerAddresses
    # `$netAdapter | Set-DnsClientServerAddress -ServerAddresses `$csl
}

Function Test-IPIsGood {
    param (
        [parameter(Mandatory = `$true)]
        [string]`$Prompt
    )

    `$ipv4 = '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)`$'
    `$ip = Read-Host `$Prompt

    while (`$ip -notmatch `$ipv4 -And `$ip -ne "") {
        Write-Host "The IP address you entered appears to be malformed. Try again."
        `$ip = Read-Host `$Prompt
    }

    return `$ip
}

Function Use-QuickImport {
    `$lines = Get-Content -Path "C:\Users\`$env:username\Desktop\ipscheme.txt"
    `$ips = ""
    `$dns = @()
    `$setting = 'ip'
    `$ipv4 = '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)`$'

    foreach (`$n in `$lines) {
        if (`$n -notmatch `$ipv4) {
            `$setting = 'dns'
        } 
        if (`$setting -eq 'ip') {
            `$ips += `$n
        }
        if (`$setting -eq 'dns' -And `$n -match `$ipv4) {
            `$dns += `$n
        }
        
    }

    Write-Host "These are the IP's"
    Write-Host `$ips

    Write-Host "These are the DNS'"
    Write-Host `$dns
}

"@

New-Item -Path "$path\$Script.ps1" -ItemType File -Force | Out-Null

Add-Content -Path "$path\$Script.ps1" -Value $core
Add-Content -Path "$path\$Script.ps1" -Value $framework
Add-Content -Path "$path\$Script.ps1" -Value "Invoke-Script '$Script'"

PowerShell.exe -NoExit -File "$path\$Script.ps1" -Verb RunAs