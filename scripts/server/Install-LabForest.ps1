#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param([Parameter(Mandatory)][securestring]$DSRMPassword)
$ErrorActionPreference='Stop'
if ($env:COMPUTERNAME -ne 'DC01') { throw 'Rename the guest DC01 and restart first. Never run on the host.' }
if ((Get-CimInstance Win32_ComputerSystem).PartOfDomain) { throw 'Guest is already domain joined; inspect instead of promoting again.' }
if ($PSCmdlet.ShouldProcess('DC01 / corp.lab','Set static lab networking, install AD DS, DNS, DHCP and promote new forest (restart)')) {
    $adapter=Get-NetAdapter | Where-Object Status -eq Up
    if (@($adapter).Count -ne 1) { throw 'DC01 must have exactly one active network adapter on the lab switch.' }
    Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -Dhcp Disabled
    Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 | Where-Object IPAddress -ne '192.168.77.10' | Remove-NetIPAddress -Confirm:$false
    if (-not (Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress '192.168.77.10' -ErrorAction SilentlyContinue)) {
        $null=New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress '192.168.77.10' -PrefixLength 24 -DefaultGateway '192.168.77.1'
    }
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses '192.168.77.10'
    $null=Install-WindowsFeature AD-Domain-Services,DNS,DHCP,Windows-Server-Backup,GPMC -IncludeManagementTools
    Install-ADDSForest -DomainName 'corp.lab' -DomainNetbiosName CORP -InstallDns -SafeModeAdministratorPassword $DSRMPassword -Force
}
