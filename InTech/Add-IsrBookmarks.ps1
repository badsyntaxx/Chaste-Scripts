function Add-IsrBookmarks {
    try {
        $profiles = [ordered]@{}
        $chromeUserDataPath = "C:\Users\$env:username\AppData\Local\Google\Chrome\User Data"
        $profileFolders = Get-ChildItem -Path $chromeUserDataPath -Directory
        foreach ($profileFolder in $profileFolders) {
            $preferencesFile = Join-Path -Path $profileFolder.FullName -ChildPath "Preferences"
            if (Test-Path -Path $preferencesFile) {
                $preferencesContent = Get-Content -Path $preferencesFile -Raw | ConvertFrom-Json
                $profileName = $preferencesContent.account_info.full_name
                $profiles["$profileName"] = $profileFolder.FullName
            }
        }

        $choice = Get-Option -Options $profiles -LineAfter -ReturnValue
        $account = $profiles["$choice"]
        $boomarksUrl = "https://drive.google.com/uc?export=download&id=1WmvSnxtDSLOt0rgys947sOWW-v9rzj9U"

        $download = Get-Download -Url $boomarksUrl -Target "$env:TEMP\Bookmarks"
        if (!$download) { throw "Unable to acquire bookmarks." }

        ROBOCOPY $env:TEMP $account "Bookmarks" /NFL /NDL /NC /NS /NP | Out-Null

        Remove-Item -Path "$env:TEMP\Bookmarks" -Force

        if (Test-Path -Path $account) {
            Write-Host
            Write-Exit -Message "The bookmarks have been added." -Script "Add-IsrBookmarks"
        }
    } catch {
        Write-Text -Type "error" -Text "Add isr error: $($_.Exception.Message)"
        Write-Exit -Script "Install-IsrNinja"
    }
}

