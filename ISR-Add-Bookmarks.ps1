$boomarksUrl = "https://drive.google.com/uc?export=download&id=1WmvSnxtDSLOt0rgys947sOWW-v9rzj9U"

$wc = New-Object System.Net.WebClient
$wc.DownloadFile($boomarksUrl, "C:\Users\$env:USERNAME\Desktop\Bookmarks")

Write-Host "   Adding Nuvia bookmarks to $app"
ROBOCOPY "C:\Users\$env:USERNAME\Desktop" "C:\Users\$env:USERNAME\AppData\Local\Google\Chrome\User Data\Default" "Bookmarks"

# Example: Force delete a file
Remove-Item -Path "C:\Users\$env:USERNAME\Desktop\Bookmarks" -Force