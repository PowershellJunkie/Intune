#------Force use of TLS 1.2------
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

#-----Custom Function to get Intune Device notes-----
Function Get-IntuneDeviceNotes{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $DeviceName
    )
    Try {
        $DeviceID = (Get-IntuneManagedDevice -filter "deviceName eq '$DeviceName'" -ErrorAction Stop).id
    }
    Catch {
        Write-Error $_.Exception.Message
        #break
    }
    $deviceId = (Get-IntuneManagedDevice -Filter "deviceName eq '$DeviceName'").id
    $Resource = "deviceManagement/managedDevices('$deviceId')"
    $properties = 'notes'
    $uri = "https://graph.microsoft.com/beta/$($Resource)?select=$properties"
    Try{
        (Invoke-MSGraphRequest -HttpMethod GET -Url $uri -ErrorAction Stop).notes
    }
    Catch{
        Write-Error $_.Exception.Message
        #break
    }
}

#-----Query Active Directory, get all Hybrid Joined Devices-----
$compget = Get-ADComputer -SearchBase "OU=<your hybrid device OU>,DC=<domain>,DC=<domain>" -Filter * -Properties Name | Select Name

#-----Automated Connection to MS Graph (not to be confused with MgGraph)-----#
#---NOTE: Requires use of secured credentials script from Credetials repository on this github---#
$365uname = "youradmin@yourdomain.com"
$AESKey = Get-Content "\\yourlocation\directory\yourkeyfile.key"
$pass = Get-Content "\\yourlocation\directory\yourencryptedpassfile.txt"
$securePwd = $pass | ConvertTo-SecureString -Key $AESKey
$365cred = New-Object System.Management.Automation.PSCredential -ArgumentList $365uname, $securePwd
$ErrorActionPreference = 'SilentlyContinue'

Connect-MsGraph -Credential $365cred

#-----Create Report Array for later use------

[System.Collections.ArrayList]$report = @()

#-----Loop through AD Query, gathering device notes for each device and adding each to the report array-----
$compget | ForEach-Object{

    $obj =$_.Name

    $val = [PSCustomObject]@{
    'Computer' = $obj;
    'Assigned' = Get-IntuneDeviceNotes -DeviceName $obj
    }
    $report.Add($val) | Out-Null
    $val=$null
    }

   # $report | Write-Output | ft
    #$report.count

#-----Convert report to HMTL readable format-----
$full = $report | Sort-Object -Property Computer | ConvertTo-Html -as Table -Fragment
$devcount = $report.Count

#-----Setup HTML body for email report-----
$Htmlbody = @" 
<html> 
<head>
<style>
body {
    Color: #252525;
    font-family: Verdana,Arial;
    font-size:11pt;
}
table {border: 1px solid rgb(104,107,112); text-align: left;}
th {background-color: #d2e3f7;border-bottom:2px solid rgb(79,129,189);text-align: left;}
tr {border-bottom:2px solid rgb(71,85,112);text-align: left;}
td {border-bottom:1px solid rgb(99,105,112);text-align: left;}
h1 {
    text-align: left;
    color:#5292f9;
    Font-size: 34pt;
    font-family: Verdana, Arial;
}
h2 {
    text-align: left;
    color:#323a33;
    Font-size: 20pt;
}
h3 {
    text-align: center;
    color:#211b1c;
    Font-size: 15pt;
}
h4 {
    text-align: left;
    color:#2a2d2a;
    Font-size: 15pt;
}
h5 {
    text-align: center;
    color:#2a2d2a;
    Font-size: 12pt;
}
a:link {
    color:#0098e5;
    text-decoration: underline;
    cursor: auto;
    font-weight: 500;
}
a:visited {
    color:#05a3b7;
    text-decoration: underline;
    cursor: auto;
    font-weight: 500;
}
</style>
</head>
<body>
<h1>Intune Inventory</h1> 
<h2>Total Hybrid Joined Devices: $devcount</h2>
<hr><br><br>
<h4>Computer Assignments</h4>
$full



</body> 
</html> 
"@ 


#------Email the report------

Send-MailMessage -To "<somerecipient>@yourdomain.com" -From "<somesender>@yourdomain.com" -Subject "Weekly Intune Inventory" -BodyAsHtml $Htmlbody -SmtpServer <yourdomain-com>.mail.protection.outlook.com 
