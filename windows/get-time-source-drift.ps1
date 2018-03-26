<#
.NOTES
	Name: get-time-source-drift.ps1
	Author: Davina Fournier
	Requires: PowerShell v3 or higher. Tested on Windows 10 in a single domain.
	Last Updated: 03/26/2018
.SYNOPSIS
	Outputs a list of IPs that have a time difference greater than 5 or that have a time source that does not match the domain time source.
.DESCRIPTION
  By default, Kerberos requires a time difference of no greater than 5 minutes to prevent replay attacks. This script imports a list of ip addresses and checks them for a time difference greater than 5 minutes. In addition, it also checks that the time source is from the domain (and thus not 'Local CMOS Clock','Free-running System Clock', etc.) If the source is incorrect or the time difference is greater than 5, then the computer's information will be written to the error log. It should be noted that the script itself can take some time to run if using a large list. Thus, for large environments, the time difference may produce false positives because of how long the script itself needs to run. In that case, either break the IP list into smaller chunks or run each individual IP in a for loop where $date is reset each time.
#>
$ips = Get-Content '\path\to\your\ips.txt'
$username = 'yourUser'
$domain = '.' ##local
$securePass = ConvertTo-SecureString -string 'yourPassword' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential "$domain\$userName", $securePass
$credentials = Get-Credential -credential $credential
$log = "$PSScriptRoot\time_diff_$(get-date -Format yyyy-MM-dd-HH).txt"
$date = (get-date).touniversaltime()

$output = Invoke-Command -ComputerName $ips -Credential $credentials -ScriptBlock {
  $date = $args[0]
  $diff = ((get-date).touniversaltime() - $date).Minutes
  $source = (w32tm.exe /query /source).trim()
  
  if(($diff -gt 5) -or ($source -notlike "*.yourdomain.com"))
  {
    $ip=get-WmiObject Win32_NetworkAdapterConfiguration| Where-Object {$_.Description -notlike "Virtualbox *"} |Where-Object {$_.Ipaddress.length -gt 1}  ###may require other filters to isolate the primary IP depending on the network setup

    $info = @()
    $object = New-Object -TypeName PSObject
    $object | Add-Member -Name 'time source' -MemberType Noteproperty -Value $source
    $object | Add-Member -Name 'hostname' -MemberType Noteproperty -Value $env:computername
    $object | Add-Member -Name 'ip' -MemberType Noteproperty -Value $ip.ipaddress[0]
    $object | Add-Member -Name 'time difference' -MemberType Noteproperty -Value $diff
    $info += $object      
    return $info
  }
} -ErrorAction SilentlyContinue -ArgumentList $date
$output| Export-Csv -NoTypeInformation -Path $log