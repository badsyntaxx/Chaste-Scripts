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

        Write-Host "  $([char]0x203A) $Prompt" -NoNewline 
        if ($IsSecure) { $userInput = Read-Host -AsSecureString } 
        else { $userInput = Read-Host }

        $errorMessage = ""

        if ($CheckExistingUser) {
            $account = Get-LocalUser -Name $userInput -ErrorAction SilentlyContinue
            if ($null -ne $account) { $errorMessage = "An account with that name already exists." }
        }
        if ($userInput -notmatch $Validate) { $errorMessage = "Invalid input. Please try again." } 
        if ($errorMessage -ne "") {
            Write-Text -Type "error" -Text $errorMessage
            if ($CheckExistingUser) { return Get-Input -Prompt $Prompt -Validate $Validate -CheckExistingUser } 
            else { return Get-Input -Prompt $Prompt -Validate $Validate }
        }
        if ($userInput.Length -eq 0 -and $Value -ne "" -and !$IsSecure) { $userInput = $Value }

        [Console]::SetCursorPosition($currPos.X, $currPos.Y)
        
        Write-Host "  $([char]0x2713) " -ForegroundColor "Green" -NoNewline
        if ($IsSecure -and ($userInput.Length -eq 0)) { Write-Host "$Prompt                                                       " } 
        else { Write-Host "$Prompt$userInput                                             " }
        if ($LineAfter) { Write-Host }
    
        return $userInput
    } catch {
        Write-Text -Type "error" -Text "Input Error: $($_.Exception.Message)"
    }
}