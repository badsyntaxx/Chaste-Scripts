# Define the path to the text file
$UserList = "C:\path\to\your\userlist.txt"

# Read the text file, assuming each line contains a username
$Users = Get-Content -Path $UserList

# Loop through each username in the text file
foreach ($Username in $Users) {
    # Create new AD User for each username
    New-ADUser -Name $Username `
        -SamAccountName $Username `
        -UserPrincipalName "$Username@domain.com" `
        -Path "OU=Users,DC=domain,DC=com" `
        -AccountPassword (ConvertTo-SecureString "Platinum1!" -AsPlainText -Force) `
        -Enabled $true
}
