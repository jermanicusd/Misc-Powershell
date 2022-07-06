#Check on Deleted AD Object

if (!($cred)) {$cred = Get-Credential}

Import-Module ActiveDirectory

$input = Read-Host "Enter UserName/ComputerName/OU"

Get-ADObject -ldapFilter:"(msDS-LastKnownRDN=$input)" -IncludeDeletedObjects

Write-Output "Is this the object you want to restore? (Y or N)"
$answer = Read-Host

if ($answer -eq "" -or $answer -eq "N") { $answer = break; $validate = $true }
if ($answer -eq "Y") { $answer = Get-ADObject -ldapFilter:"(msDS-LastKnownRDN=$input)" -IncludeDeletedObjects | Restore-ADObject; $validate = $true }
