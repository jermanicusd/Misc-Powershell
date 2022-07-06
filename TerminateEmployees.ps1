<#

.SYNOPSIS
This is for terminating users at *companyname*

.DESCRIPTION
1. Moves user to termed employees and edits description
2. Removes group memberships in AD
3. Removes license from o365
4. Creates scheduled task that will run in 30days to rerun this script with -finalpass switch which will:
    - Move user to disabledaccounts OU
    - Disable account

.EXAMPLE
-Need to use account name
.\Terminate-User.ps1 -termuser Tname

Terminate-User.ps1 -termuser Tkonsonlas -finalpass

.NOTES
V1 - 02/20/2020 - JD

#>


[CmdletBinding(DefaultParameterSetName = 'User')]
param(
    [Parameter(Mandatory = $true,Position = 0,ParameterSetName = 'User')]
    [String]$TermUser,

    [Parameter(Mandatory = $false)]
    [switch]
    $FinalPass
)

#------------------------------------------------------------------------------------------------------------#

#Modules
Import-Module ActiveDirectory
Import-Module AzureAD
Import-Module ExchangeOnlineManagement

#------------------------------------------------------------------------------------------------------------#

#$TermUser = "tdiaz2"
$TUser = Get-ADUser $TermUser
$Domain = Read-Host "Enter domain (eg. contoso.com)"
$Email = "$Termuser@$Domain"

if ($null -eq $TUser) {
    Write-Error "Could not find $TermUser in Active Directory"
    Exit
}

if (($TUser.distinguishedname -like "*OU=DisabledAccounts*") -and ($TUser.Enabled -eq $False)) {
    Write-Error "$TermUser is already located in DisabledAccounts and disabled"
    Exit
}

#------------------------------------------------------------------------------------------------------------#

#Disable user and move to Disabled OU (Part ran by scheduled task)
If ($FinalPass) {
    Get-ADUser $termUser | Move-ADObject -TargetPath 'OU=DisabledAccounts,DC=corp,DC=hrg'-ErrorVariable DAmoveerror
    Start-Sleep -Seconds 5
    Get-ADUser $termUser | Disable-ADAccount -ErrorVariable DisableError
    if (!($DAmoveerror -or $DisableError)) {
    Write-Output "**Moved and disabled user: $TermUser"
    } else {
        #Error Catching
        Write-Error "Unable to move user to DisabledAccounts. DAmoveerror is $DAmoveerror"
        Write-Error "Unable to disable user. DisableError is $DisableError"
    }
    Exit
}

#------------------------------------------------------------------------------------------------------------#

#Vars
$TermDate = get-date -uformat "%m-%d-%Y"
$Incident = Read-Host "Enter incident number:"
$TermUserDescription = "Terminated $TermDate - Incident $Incident"
$DCDistinguishedName = ""

#Move user to Termed_Employees and change description
Get-ADUser $TermUser | Move-ADObject -TargetPath "OU=Termed_Employees,OU=Non_Employee,OU=HRG_USERS," + $DCDistinguishedName -ErrorVariable TEmoveerror
Start-Sleep -Seconds 5
Get-ADUser $TermUser | Set-ADUser -Description $TermUserDescription -ErrorVariable DescriptionError

#Error Catching
if (!($TEmoveerror -or $DescriptionError)) {
    Write-Output "Successfully moved, and edited description $TermUser"
} else {
    Write-Error "Unable to move $TermUser to Termed_Employees. $TEmoveerror"
    Write-Error "Unable to set discription for $TermUser. $DescriptionError"
}

#Remove Group Memberships
while ($null -eq ($TermUser | Get-ADPrincipalGroupMembership)) {
Start-Sleep -s 2
}

Write-Output "**Saving group memberships to csv"
$TermUser | Get-ADPrincipalGroupMembership | Select-Object @{N="User";E={$TUser.sAMAccountName}},@{N="Group";E={$_.Name}} | Select-Object User,Group | Export-Csv "$PSScriptRoot\TermedUserGroups.csv" -NoTypeInformation -Append

function RemoveGroups {
    foreach ($Group in $Groups) {
        Remove-ADPrincipalGroupMembership -Identity $TermUser -MemberOf $Group.name -Confirm:$False -ErrorVariable GroupError
        if ($GroupError) {
            Write-Error "Unable to remove user from a group. $GroupError"
        }
    }
}

Write-Output "**Removing group memberships"
$Groups = Get-ADPrincipalGroupMembership $TermUser | Where-Object {$_.name -notlike "LDAP"}
if ($null -ne $Groups) {RemoveGroups}

#------------------------------------------------------------------------------------------------------------#
#Check if signed into exchange online
try
{
    Get-MsolDomain -ErrorAction Stop | Out-Null
}
catch
{
    Write-Output "**Connecting to Office 365..."
    Connect-MsolService
}

#Remove O365 license
$UPN = (Get-MsolUser -SearchString $TermUser).UserPrincipalName
$licenselist = (Get-MsolUser -SearchString $TermUser).licenses
$O365license = $Licenselist.accountskuid
Write-Output "**Removing O365 License"
Set-MsolUserLicense -UserPrincipalName $UPN -RemoveLicenses $O365license -ErrorVariable licenseerror

#LicenseError Catch
if ($licenseerror) {
    Write-Error "There was an issue removing the O365 license. $licenseerror"
}

#------------------------------------------------------------------------------------------------------------#

#Create scheduled task to disable user in 30days, removes itself after
Write-Output "**Creating Scheduled task to disable user in 30 days"
$now = Get-Date
$30days = $now.AddDays(30)
$1hour = $now.AddHours(1)
$expire1h = $1hour.AddHours(2).ToString('s')
$expire30d = $30days.AddDays(1).ToString('s')

$Credentials = Get-Credential -UserName "$env:USERDOMAIN\$env:USERNAME" -Message "Enter credentials for scheduled task"
$Password = $Credentials.GetNetworkCredential().Password

$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-noninteractive -NoLogo -NoProfile $PSScriptRoot\Terminate-User.ps1 $termuser -finalpass" -WorkingDirectory "$PSScriptRoot"
$Trigger = New-ScheduledTaskTrigger -Once -At $30days
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable
$Settings.DeleteExpiredTaskAfter = 'PT5M'
$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Settings $Settings
$task.Triggers[0].EndBoundary = $expire30d
Register-ScheduledTask -TaskName "Disable $TermUser" -InputObject $Task -User "$env:USERDOMAIN\$env:USERNAME" -Password $Password
