function Add-IsrBookmarks {
    $profiles = [ordered]@{}

    # Specify the path to the Chrome user data directory
    $chromeUserDataPath = "C:\Users\$env:username\AppData\Local\Google\Chrome\User Data"

    # Get a list of all subdirectories (profile folders) within the user data directory
    $profileFolders = Get-ChildItem -Path $chromeUserDataPath -Directory

    # Iterate through each profile folder and extract the profile name
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

    Write-Text "Adding Nuvia bookmarks to $app"
    ROBOCOPY $env:TEMP $account "Bookmarks"

    if (Test-Path -Path $account) {
        Write-Text -Type "done" -Text "The bookmarks were successfully added"
    }

    # Example: Force delete a file
    Remove-Item -Path "$env:TEMP" -Force
}

