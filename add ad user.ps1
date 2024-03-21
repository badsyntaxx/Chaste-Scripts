# Read the domain name from user input
$domainName = Read-Host 'Enter domain name'

# Define the path to the text file
$UserList = "C:\Users\$env:username\Desktop\Users.txt"

# Read the text file, assuming each line contains a username
$users = Get-Content -Path $UserList

# Loop through each username in the text file
foreach ($user in $users) {
    # Split the user data
    $userData = $user.Split(' ')
    $Name = $userData[0]
    $SamAccountName = $userData[1]
    $GivenName = $userData[2]
    $Surname = $userData[3]
    $UserPrincipalName = $userData[4]

    Write-Host "New-ADUser -Name $Name -SamAccountName $SamAccountName -GivenName $GivenName -Surname $Surname -UserPrincipalName `"$UserPrincipalName@$domainName.com`" -AccountPassword (ConvertTo-SecureString `"Platinum1!`" -AsPlainText -Force) -Enabled $true"
    # Create new AD User for each username
    <# New-ADUser -Name $Name 
        -SamAccountName $SamAccountName 
        -GivenName $GivenName 
        -Surname $Surname 
        -UserPrincipalName "$UserPrincipalName@$domainName.com" 
        -AccountPassword (ConvertTo-SecureString "Platinum1!" -AsPlainText -Force) 
        -Enabled $true #>
}

