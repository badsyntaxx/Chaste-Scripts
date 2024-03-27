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

        $choice = Get-Option -Options $profiles -LineAfter -ReturnKey
        $account = $profiles["$choice"]
        $boomarksUrl = "https://drive.google.com/uc?export=download&id=1WmvSnxtDSLOt0rgys947sOWW-v9rzj9U"

        $download = Get-Download -Url $boomarksUrl -Target "$env:TEMP\Bookmarks"
        if (!$download) { throw "Unable to acquire bookmarks." }

        ROBOCOPY $env:TEMP $account "Bookmarks" /NFL /NDL /NC /NS /NP | Out-Null

        Remove-Item -Path "$env:TEMP\Bookmarks" -Force

        $preferencesFilePath = Join-Path -Path $profiles["$choice"] -ChildPath "Preferences"
        if (Test-Path -Path $preferencesFilePath) {
            $preferences = Get-Content -Path $preferencesFilePath -Raw | ConvertFrom-Json
            if (-not $preferences.PSObject.Properties.Match('bookmark_bar').Count) {
                $preferences | Add-Member -Type NoteProperty -Name 'bookmark_bar' -Value @{}
            }

            if (-not $preferences.bookmark_bar.PSObject.Properties.Match('show_on_all_tabs').Count) {
                $preferences.bookmark_bar | Add-Member -Type NoteProperty -Name 'show_on_all_tabs' -Value $true
            } else {
                $preferences.bookmark_bar.show_on_all_tabs = $true
            }

            $preferences | ConvertTo-Json -Depth 100 | Set-Content -Path $preferencesFilePath
        } else {
            throw "Preferences file not found."
        }

        if (Test-Path -Path $account) {
            Write-Host
            Write-Exit -Message "The bookmarks have been added." -Script "Add-IsrBookmarks"
        }
    } catch {
        Write-Text -Type "error" -Text "Add isr error: $($_.Exception.Message)"
        Write-Exit -Script "Install-IsrNinja"
    }
}

