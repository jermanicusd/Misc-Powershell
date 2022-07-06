# ----- Adds computer to OU of user's choice in Active Directory ----- #
# ----- Edit Variables for your own Use Case ----- #

#Checks if credentails are in session and if not asks for credentials 
if (!($cred)) {$cred = Get-Credential}

$computername = Read-Host “Please enter your desired computer name: [Default $env:computername]”
$renamecomputer = $true
if ($computername -eq "" -or $computername -eq $env:computername) { $computername = $env:computername; $renamecomputer = $false }
if ($renamecomputer -eq $true) { Rename-Computer -NewName $computername -DomainCredential $credentials -Force -Restart:$false}
$domain = Read-Host "Enter Domain to join"
$DC = Read-host "Enter Domain Component of Distinguished Name"

#Prompt for OU choice
Write-Host -ForegroundColor Cyan "Please select the OU [1-9] [Default 1]:
1. NA
2. Denver
3. Chicago
4. LA
5. Lab
6. Tuscon
7. SanFran
8. Seattle
9. Scranton"

$ou = Read-Host

$validate = $false
if ($ou -eq "" -or $ou -eq "1") { $ou = "OU=NA,OU=PCs,OU=GBC Computers,DC=" + $DC + ",DC=org"; $validate = $true }
if ($ou -eq "2") { $ou = "OU=Denver,OU=PCs,OU=GBC Computers,DC=" + $DC + ",DC=org"; $validate = $true }
if ($ou -eq "3") { $ou = "OU=Chicago,OU=PCs,OU=GBC Computers,DC=" + $DC + ",DC=org"; $validate = $true }
if ($ou -eq "4") { $ou = "OU=LA,OU=PCs,OU=GBC Computers,DC=" + $DC + ",DC=org"; $validate = $true }
if ($ou -eq "5") { $ou = "OU=Lab,OU=PCs,OU=GBC Computers,DC=" + $DC + ",DC=org"; $validate = $true }
if ($ou -eq "6") { $ou = "OU=Tuscon,OU=PCs,OU=GBC Computers,DC=" + $DC + ",DC=org"; $validate = $true }
if ($ou -eq "7") { $ou = "OU=SanFran,OU=PCs,OU=GBC Computers,DC=" + $DC + ",DC=org"; $validate = $true }
if ($ou -eq "8") { $ou = "OU=Seattle,OU=PCs,OU=GBC Computers,DC=" + $DC + ",DC=org"; $validate = $true }
if ($ou -eq "9") { $ou = "OU=Scranton,OU=PCs,OU=GBC Computers,DC=" + $DC + ",DC=org"; $validate = $true }
if ($validate -eq $false) { Write-Output "Invalid input, defaulting to [1]."; $ou = "OU=NA,OU=PCs,OU=GBC Computers,DC=" + $DC + ",DC=org"}

#Adds current computer to the domain
Write-Output "Adding  $env:computername to the domain"
Add-Computer -DomainName $domain -Credential $cred -OUPath $ou

#adds 5 second pause
Start-Sleep -Seconds 5

#restarts computer after joining domain
Restart-Computer  
