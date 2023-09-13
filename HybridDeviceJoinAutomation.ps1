<#
Automation intended to get freshly joined computers
- by naming convention 
- add them to the correct device groups
- place them in the Hybrid Joined Devices OU (determined by you) 
- then force syncronization for local DC's
- then force syncronization out to Azure

This is intended to be used in a hybrid joined scenario where local security groups (to be device only groups) are synced out to Azure.
Devices will be added to those groups by this automation
The groups will be assigned to Intune software deployment packages
After all relevant data has syncronized and the device has been registered with Intune as the MDM, Intune will deploy all relevant software packages based on the device's group memberships
#>

# Query the default Computers OU
$computers = Get-ADComputer -Filter * -SearchBase "CN=Computers,DC=<domain>,DC=<com>" | Select Name

# Leverage previous query to differentiate between various naming conventions for the purpose of assigning devices to appropriate device groups for software installations
#--Naming conventions here are to approximate by typical computer type. Each 'workstation', 'server' or 'tablet' signifier can be replaced by any relevant naming convention, be it letters or numbers
$workstations = $computers | Where {$_.Name -like '*Workstation*' -and $_.Name -notlike '*Server*' -and $_.Name -notlike '*Tablet*'}
$laptops = $computers | Where {$_.Name -like '*Laptop*' -and $_.Name -notcontains '*Workstation*' -and $_.Name -notlike '*Server*' -and $_.Name -notlike '*Tablet*'}
$training = $computers | Where {$_.Name -like '*-Training*' -and $_.Name -notlike '*Server*' -and $_.Name -notlike '*Tablet*'}
$test = $computers | Where {$_.Name -like '*TEST-*'}

<#
  From here, there are 2 loops per grouping of machines from the previous section of variable definitions (naming conventions).
  The first loops adds the device to the relevant groups, based on the naming conventions
  The second loop identifies the relevant information and then moves the PC to the Hybrid joined OU, where the Azure tool can gather/write/sync the appropriate device information
  Only 1 of each loop is present in this skeleton, but simply copying each loop and renaming as appropriate will allow you to expand this script's capabilities to meet your needs
#>

# Add devices to relevant groups
$test | ForEach-Object{
	
	$obj = $_.Name
	$pooter = Get-ADComputer $obj | Select sAMAccountName
	Add-ADGroupMember -Identity "ADFSSyncGroup" -Members $pooter
	Add-ADGroupMember -Identity "ExampleGroup1" -Members $pooter
	
	
}

# Move test machines to the proper OU to be synced
$test | ForEach-Object{
	$name = $_.Name
	Get-ADComputer $name | Move-ADObject -TargetPath "OU=Hybrid Joined Devices,DC=<domain>,DC=<com>"
	
}

# Force replication to all DC's

$dcsession = New-PSSession -ComputerName <your DC name>
$dcscript = {repadmin /syncall}
Invoke-Command -Session $dcsession -ScriptBlock $dcscript
Remove-PSSession $dcsession



# Force Sync to Azure to begin device details upload/export
$session = New-PSSession -ComputerName <your syncronization server name>
$script = {Start-ADSyncSyncCycle -PolicyType Delta}
Invoke-Command -Session $session -ScriptBlock $script
Remove-PSSession $session
