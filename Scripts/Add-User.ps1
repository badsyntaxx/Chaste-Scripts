if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

function Add-User {
    try {
        $scriptDescription = @"
 Create new local and / or domain users.
"@

        Get-Item -ErrorAction SilentlyContinue "$scriptPath\Add-User.ps1" | Remove-Item -ErrorAction SilentlyContinue
        Write-Host " Chaste Scripts: Add User v0315241122"
        Write-Host "$scriptDescription" -ForegroundColor DarkGray

        Write-Text -Type "header" -Text "What type of user do you want to add?" -LineBefore -LineAfter

        $choice = Get-Option -Options $([ordered]@{
                'Local'  = 'Create a local user.' 
                'Domain' = 'Create a domain user.'
            })

        if ($choice -eq 0) { 
            irm chaste.dev/add/local/user | iex
        }
        if ($choice -eq 1) { 
            irm chaste.dev/add/ad/user | iex
        }
    } catch {
        Write-Text -Type "error" -Text "Add user error: $($_.Exception.Message)"
        Write-Exit
    }
}