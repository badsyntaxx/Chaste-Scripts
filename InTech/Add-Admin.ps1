function Add-Admin {
    try {
        Write-Welcome -Title "Add InTechAdmin Account" -Description "Add an InTech administrator account to this PC." -Command "intech add admin"

        Write-Text -Type "header" -Text "Getting credentials" -LineBefore -LineAfter

        $isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
        $path = if ($isAdmin) { "$env:SystemRoot\Temp" } else { "$env:TEMP" }
        $accountName = "InTechAdmin"

        $downloads = [ordered]@{
            "$path\KEY.txt"    = "https://drive.google.com/uc?export=download&id=1EGASU9cvnl5E055krXXcXUcgbr4ED4ry"
            "$path\PHRASE.txt" = "https://drive.google.com/uc?export=download&id=1jbppZfGusqAUM2aU7V4IeK0uHG2OYgoY"
        }

        foreach ($d in $downloads.Keys) { $download = Get-Download -Url $downloads[$d] -Target $d } 
        if (!$download) { throw "Unable to acquire credentials." }

        $password = Get-Content -Path "$path\PHRASE.txt" | ConvertTo-SecureString -Key (Get-Content -Path "$path\KEY.txt")

        Write-Text -Type "done" -Text "Credentials acquired."

        $account = Get-LocalUser -Name $accountName -ErrorAction SilentlyContinue

        if ($null -eq $account) {
            Write-Text -Type "header" -Text "Creating account" -LineBefore -LineAfter
            New-LocalUser -Name $accountName -Password $password -FullName "" -Description "InTech Administrator" -AccountNeverExpires -PasswordNeverExpires -ErrorAction stop | Out-Null
            Write-Text -Type "done" -Text "Account created."

            Add-LocalGroupMember -Group "Administrators" -Member $accountName -ErrorAction stop
            Write-Text -Type "done" -Text "Group assignment successful." -LineAfter

            $finalMessage = "Success! The InTechAdmin account has been created."
        } else {
            Write-Text -Type "notice" -Text "InTechAdmin account already exists!" -LineBefore -LineAfter
            Write-Text -Text "Updating password..."
            $account | Set-LocalUser -Password $password
            Write-Text -Text "Updating group membership..."
            Add-LocalGroupMember -Group "Administrators" -Member $accountName -ErrorAction SilentlyContinue
            Add-LocalGroupMember -Group "Remote Desktop Users" -Member $accountName -ErrorAction SilentlyContinue
            Add-LocalGroupMember -Group "Users" -Member $accountName -ErrorAction SilentlyContinue

            $finalMessage = "Success! The password was updated and the groups were applied."
        }

        Remove-Item -Path "$path\PHRASE.txt"
        Remove-Item -Path "$path\KEY.txt"

        Write-Exit -Message $finalMessage -Script "Intech-AddAdmin"
    } catch {
        Write-Text -Type "error" -Text "Create IntechAdmin Error: $($_.Exception.Message)"
        Write-Exit -Script "Intech-AddAdmin"
    }
}
