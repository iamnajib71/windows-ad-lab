#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param()
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory
Import-Module DhcpServer
if ($env:COMPUTERNAME -ne 'DC01' -or (Get-ADDomain).DNSRoot -ne 'corp.lab') { throw 'Run on DC01 in corp.lab only.' }
if ($PSCmdlet.ShouldProcess('corp.lab','Create lab OUs, AGDLP groups, DNS/DHCP, account policy and enable Recycle Bin')) {
    $dn='DC=corp,DC=lab'
    foreach ($name in @('Staff','Admins','Lab','Disabled','Groups')) {
        if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$name'" -SearchBase $dn -SearchScope OneLevel)) {
            New-ADOrganizationalUnit -Name $name -Path $dn -ProtectedFromAccidentalDeletion $true
        }
    }
    # The domain root already contains the built-in CN=Computers container.
    $computerParent="OU=Lab,$dn"
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Computers'" -SearchBase $computerParent -SearchScope OneLevel)) {
        New-ADOrganizationalUnit -Name Computers -Path $computerParent -ProtectedFromAccidentalDeletion $true
    }
    foreach ($department in @('Finance','HR','IT')) {
        foreach ($parent in @('Staff','Groups')) {
            $path="OU=$parent,$dn"
            if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$department'" -SearchBase $path -SearchScope OneLevel)) {
                New-ADOrganizationalUnit -Name $department -Path $path -ProtectedFromAccidentalDeletion $true
            }
        }
        foreach ($spec in @(@{Name="GG_$department";Scope='Global'},@{Name="DL_${department}_Modify";Scope='DomainLocal'})) {
            if (-not (Get-ADGroup -Filter "Name -eq '$($spec.Name)'")) {
                New-ADGroup -Name $spec.Name -GroupScope $spec.Scope -GroupCategory Security -Path "OU=$department,OU=Groups,$dn"
            }
        }
        Add-ADGroupMember -Identity "DL_${department}_Modify" -Members "GG_$department"
    }
    Set-ADDefaultDomainPasswordPolicy -Identity 'corp.lab' -MinPasswordLength 14 -ComplexityEnabled $true -PasswordHistoryCount 24 -MaxPasswordAge (New-TimeSpan -Days 90) -MinPasswordAge (New-TimeSpan -Days 1) -LockoutThreshold 5 -LockoutDuration (New-TimeSpan -Minutes 15) -LockoutObservationWindow (New-TimeSpan -Minutes 15) -ReversibleEncryptionEnabled $false
    $feature=Get-ADOptionalFeature -Identity 'Recycle Bin Feature'
    if (-not $feature.EnabledScopes) { Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target 'corp.lab' -Confirm:$false }
    if (-not (Get-DnsServerZone -Name '77.168.192.in-addr.arpa' -ErrorAction SilentlyContinue)) {
        Add-DnsServerPrimaryZone -NetworkId '192.168.77.0/24' -ReplicationScope Domain
    }
    Set-DnsServerForwarder -IPAddress '1.1.1.1','9.9.9.9'
    Add-DhcpServerSecurityGroup
    if (-not (Get-DhcpServerInDC | Where-Object DnsName -eq 'DC01.corp.lab')) {
        Add-DhcpServerInDC -DnsName 'DC01.corp.lab' -IPAddress '192.168.77.10'
    }
    if (-not (Get-DhcpServerv4Scope -ScopeId '192.168.77.0' -ErrorAction SilentlyContinue)) {
        Add-DhcpServerv4Scope -Name 'CORP Lab' -StartRange '192.168.77.100' -EndRange '192.168.77.150' -SubnetMask '255.255.255.0' -State Active
    }
    Set-DhcpServerv4OptionValue -ScopeId '192.168.77.0' -DnsDomain 'corp.lab' -DnsServer '192.168.77.10' -Router '192.168.77.1'
    Set-DhcpServerv4Binding -InterfaceAlias (Get-NetAdapter | Where-Object Status -eq Up).Name -BindingState $true
    Restart-Service DHCPServer
}
