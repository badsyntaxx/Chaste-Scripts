function Get-Option {
    param (
        [parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Options,
        [parameter(Mandatory = $false)]
        [switch]$ReturnValue = $false,
        [parameter(Mandatory = $false)]
        [switch]$LineBefore = $false,
        [parameter(Mandatory = $false)]
        [switch]$LineAfter = $false
    )

    try {
        if ($LineBefore) { Write-Host }
        $vkeycode = 0
        $pos = 0
        $oldPos = 0
        $orderedKeys = $Options.Keys | ForEach-Object { $_ }
        $longestKeyLength = ($orderedKeys | Measure-Object -Property Length -Maximum).Maximum

        if ($orderedKeys.Count -eq 1) {
            Write-Host "  $([char]0x203A) $($orderedKeys) $(" " * ($longestKeyLength - $orderedKeys.Length)) - $($Options[$orderedKeys])" -ForegroundColor "Cyan"
        } else {
            for ($i = 0; $i -lt $orderedKeys.Count; $i++) {
                $key = $orderedKeys[$i]
                $padding = " " * ($longestKeyLength - $key.Length)
                if ($i -eq $pos) { Write-Host "  $([char]0x203A) $key $padding - $($Options[$key])" -ForegroundColor "Cyan" } 
                else { Write-Host "    $key $padding - $($Options[$key])" -ForegroundColor "White" }
            }
        }

        $currPos = $host.UI.RawUI.CursorPosition

        While ($vkeycode -ne 13) {
            $press = $host.ui.rawui.readkey("NoEcho, IncludeKeyDown")
            $vkeycode = $press.virtualkeycode
            Write-host "$($press.character)" -NoNewLine
            if ($orderedKeys.Count -ne 1) { 
                $oldPos = $pos;
                if ($vkeycode -eq 38) { $pos-- }
                if ($vkeycode -eq 40) { $pos++ }
                if ($pos -lt 0) { $pos = 0 }
                if ($pos -ge $orderedKeys.Count) { $pos = $orderedKeys.Count - 1 }

                $menuLen = $orderedKeys.Count
                $menuOldPos = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen - $oldPos)))
                $menuNewPos = New-Object System.Management.Automation.Host.Coordinates(0, ($currPos.Y - ($menuLen - $pos)))
                $oldKey = $orderedKeys[$oldPos]
                $newKey = $orderedKeys[$pos]
            
                $host.UI.RawUI.CursorPosition = $menuOldPos
                Write-Host "    $($orderedKeys[$oldPos]) $(" " * ($longestKeyLength - $oldKey.Length)) - $($Options[$orderedKeys[$oldPos]])" -ForegroundColor "White"
                $host.UI.RawUI.CursorPosition = $menuNewPos
                Write-Host "  $([char]0x203A) $($orderedKeys[$pos]) $(" " * ($longestKeyLength - $newKey.Length)) - $($Options[$orderedKeys[$pos]])" -ForegroundColor "Cyan"
                $host.UI.RawUI.CursorPosition = $currPos
            }
        }

        if ($LineAfter) { Write-Host }
        if ($ReturnValue) { if ($orderedKeys.Count -eq 1) { return $orderedKeys } else { return $orderedKeys[$pos] } } 
        else { return $pos }
    } catch {
        Write-Host "  $($_.Exception.Message)" -ForegroundColor "Red"
    }
}