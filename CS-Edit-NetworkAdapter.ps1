Function Initialize-NetworkAdapterEditor {
    Enable-RunAsAdministrator
    Confirm-StartingChoice
    Wait-ForKey
}

Function Enable-RunAsAdministrator {
    $CurrentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($CurrentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-host "Script is running with Administrator privileges!"
    } else {
        $ElevatedProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";
        $ElevatedProcess.Arguments = "& '" + $script:MyInvocation.MyCommand.Path + "'"
        $ElevatedProcess.Verb = "runas"
        [System.Diagnostics.Process]::Start($ElevatedProcess)
        Write-Host "Script has been elevated."
        Exit
    }
}

Function Confirm-StartingChoice {
    $title = "NETWORK ADAPTER EDITOR"
    $prompt = "Start by viewing or selecting a network adapters?"
    $choices = @(
        (New-Object System.Management.Automation.Host.ChoiceDescription "Display &Adapters", "Display a list of network adapters."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Display Adapters(Detailed)", "Display a more detailed list of network adapters."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Select Adapter", "Select a network adapter."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Quit", "Quit and exit.")
    )
    $default = 0
    $choice = $host.UI.PromptForChoice($title, $prompt, $choices, $default)

    if (0 -eq $choice) { Show-Adapters }
    if (1 -eq $choice) { Show-AdaptersDetailed }
    if (2 -eq $choice) { Select-Adapter }
    if (3 -eq $choice) { Exit }
}

Function Select-Adapter {
    Clear-Host
    $adapters = @()

    foreach ($n in (Get-NetAdapter | Select-Object -ExpandProperty Name)) {
        $adapters += $n
    }

    $i = 1
    $choices = @()
    foreach ($n in $adapters) {
        $choices += (New-Object System.Management.Automation.Host.ChoiceDescription "&$i.$n,")
        $i++
    }

    $choice = $host.UI.PromptForChoice("", "Select a network adapter", $choices, 0)
    $global:adapterName = $adapters[$choice]
    $global:netAdapter = Get-NetAdapter -Name $adapterName
    $global:adapterIndex = $netAdapter.InterfaceIndex
    $ipData = Get-NetIPAddress -InterfaceIndex $adapterIndex | Select-Object -First 1
    $global:currentIP = $ipData.IPAddress
    $global:currentGateway = (Get-NetRoute | Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' }).NextHop
    $global:currentSubnet = Convert-CIDRToMask -CIDR $ipData.PrefixLength
    $interface = Get-NetIPInterface -InterfaceIndex $adapterIndex
    $global:currentAssignment = $(if ($interface.Dhcp -eq "Enabled") { "DHCP" } else { "Static" })

    Select-QuickOrNormal
}

Function Convert-CIDRToMask {
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

Function Select-QuickOrNormal {
    Clear-Host
    $title = "NETWORK ADAPTER: $adapterName"
    $prompt = "Would you like to QUICK IMPORT using a text file?"
    $choices = @(
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Use a (.txt) file to quickly import IP and DNS settings."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Enter the settings yourself."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Back", "Go back to adapter selection.")
    )
    $default = 0
    $choice = $host.UI.PromptForChoice($title, $prompt, $choices, $default)

    if (0 -eq $choice) { Select-QuickImport }
    if (1 -eq $choice) { Edit-IP }
    if (2 -eq $choice) { Select-Adapter }
}

Function Show-AdaptersDetailed {
    netsh interface ipv4 show config
    Confirm-StartingChoice
}

Function Show-Adapters {
    Get-NetAdapter
    Confirm-StartingChoice
}

Function Edit-IP {
    Clear-Host
    $title = "NETWORK ADAPTER: $adapterName"
    $prompt = "Set to DHCP or set to static and enter IP data manually"
    $choices = @(
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Manual", "Set the IP's to static and type the IP data."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&DHCP", "Set the adapter to DHCP."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Back", "Go back to quick import selection.")
    )
    $default = 0
    $choice = $host.UI.PromptForChoice($title, $prompt, $choices, $default)
    $global:IPDHCP = $false

    if (0 -eq $choice) { 
        $global:desiredAddress = Test-IPIsGood -Prompt "Enter IP Address (Leave blank to skip)"
        $global:desiredSubnet = Test-IPIsGood -Prompt "Enter Subnet mask (Leave blank to skip)"        
        $global:desiredGateway = Test-IPIsGood -Prompt "Enter Gateway (Leave blank to skip)"

        if ("" -eq $desiredAddress) { $desiredAddress = $currentIP }
        if ("" -eq $desiredSubnet) { $desiredSubnet = $currentSubnet }
        if ("" -eq $desiredGateway) { $desiredGateway = $currentGateway }
    }
    if (1 -eq $choice) { $global:IPDHCP = $true }
    if (2 -eq $choice) { Select-QuickOrNormal }

    Edit-DNS
}

Function Set-IPScheme {
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

Function Edit-DNS {
    $title = "NETWORK ADAPTER: $adapterName"
    $prompt = "Set to DHCP or set to static and enter the DNS data manually"
    $choices = @(
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Manual", "Set DNS to static and type the DNS data."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&DHCP", "Set the DNS to DHCP."),
        (New-Object System.Management.Automation.Host.ChoiceDescription "&Back", "Go back to IP entry.")
    )
    $default = 0
    $choice = $host.UI.PromptForChoice($title, $prompt, $choices, $default)
    $global:DNSDHCP = $false

    if (0 -eq $choice) { 
        $global:dns = New-Object System.Collections.Generic.List[System.Object]
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
    if (1 -eq $choice) { $global:DNSDHCP = $true }
    if (2 -eq $choice) { Edit-IP }

    Confirm-Edits
}

Function Confirm-Edits {
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

Function Test-IPIsGood {
    param (
        [parameter(Mandatory = $true)]
        [string]$Prompt
    )

    $ipv4 = '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    $ip = Read-Host $Prompt

    while ($ip -notmatch $ipv4 -And $ip -ne "") {
        Write-Host "The IP address you entered appears to be malformed. Try again."
        $ip = Read-Host $Prompt
    }

    return $ip
}

Function Use-QuickImport {
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

Function Wait-ForKey {
    Write-Host
    Write-Host "Press any key to continue..." -ForegroundColor Black -BackgroundColor White
    [Console]::ReadKey($true) | Out-Null
}

Initialize-NetworkAdapterEditor