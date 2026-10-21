#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param([Parameter(Mandatory)][pscredential]$DomainCredential)
$ErrorActionPreference='Stop'
if ($env:COMPUTERNAME -ne 'CLIENT01') { throw 'Run inside the renamed CLIENT01 VM only.' }
if ((Get-CimInstance Win32_ComputerSystem).PartOfDomain) { throw 'Already domain joined; inspect existing membership.' }
if ($PSCmdlet.ShouldProcess('CLIENT01','Set DNS and join corp.lab / Computers OU (restart)')) {
    $adapter=Get-NetAdapter | Where-Object Status -eq Up
    if (@($adapter).Count -ne 1) { throw 'Use one adapter on the lab switch.' }
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses '192.168.77.10'
    $null=Resolve-DnsName '_ldap._tcp.dc._msdcs.corp.lab' -Type SRV -Server '192.168.77.10'
    Add-Computer -DomainName 'corp.lab' -OUPath 'OU=Computers,OU=Lab,DC=corp,DC=lab' -Credential $DomainCredential -Restart
}
