# Run manually on DC01 after deployment/onboarding; excluded from offline CI.
BeforeAll {
    if ($env:COMPUTERNAME -ne 'DC01') { throw 'Acceptance requires the actual DC01 guest.' }
    Import-Module ActiveDirectory
    Import-Module GroupPolicy
    Import-Module DhcpServer
}
Describe 'Real DC01 services and directory' {
    It 'is the corp.lab Microsoft AD forest' { (Get-ADDomain).DNSRoot | Should -Be 'corp.lab' }
    It 'has running ADWS, DNS and DHCP' {
        foreach ($name in @('ADWS','DNS','DHCPServer')) { (Get-Service $name).Status | Should -Be Running }
    }
    It 'has the required protected OUs' {
        foreach ($name in @('Staff','Admins','Computers','Disabled','Groups')) {
            (Get-ADOrganizationalUnit -Identity "OU=$name,DC=corp,DC=lab" -Properties ProtectedFromAccidentalDeletion).ProtectedFromAccidentalDeletion | Should -BeTrue
        }
    }
    It 'authorises DC01 DHCP with the intended DNS options' {
        @(Get-DhcpServerInDC | Where-Object DnsName -eq 'DC01.corp.lab').Count | Should -Be 1
        (Get-DhcpServerv4Scope -ScopeId 192.168.77.0).State | Should -Be Active
        (Get-DhcpServerv4OptionValue -ScopeId 192.168.77.0 -OptionId 6).Value | Should -Contain '192.168.77.10'
    }
    It 'resolves domain controller LDAP SRV records' {
        @(Resolve-DnsName _ldap._tcp.dc._msdcs.corp.lab -Type SRV -Server 192.168.77.10 | Where-Object NameTarget -eq 'dc01.corp.lab').Count | Should -BeGreaterThan 0
    }
    It 'has the expected domain password and lockout settings' {
        $policy=Get-ADDefaultDomainPasswordPolicy
        $policy.MinPasswordLength | Should -Be 14
        $policy.LockoutThreshold | Should -Be 5
        $policy.ComplexityEnabled | Should -BeTrue
    }
    It 'has enabled Recycle Bin' { @((Get-ADOptionalFeature 'Recycle Bin Feature').EnabledScopes).Count | Should -BeGreaterThan 0 }
    It 'has CLIENT01 in the intended Computers OU' {
        (Get-ADComputer CLIENT01).DistinguishedName | Should -BeLike '*,OU=Computers,DC=corp,DC=lab'
    }
    It 'has the department resource group nesting and ABE shares' {
        foreach ($department in @('Finance','HR','IT')) {
            (Get-ADGroupMember "DL_${department}_Modify").Name | Should -Contain "GG_$department"
            (Get-SmbShare -Name $department).FolderEnumerationMode | Should -Be AccessBased
            $grants=@(Get-SmbShareAccess -Name $department)
            @($grants | Where-Object { $_.AccountName -eq "CORP\DL_${department}_Modify" -and $_.AccessRight -eq 'Change' }).Count | Should -Be 1
            @($grants | Where-Object AccountName -eq Everyone).Count | Should -Be 0
        }
    }
    It 'has all named GPOs with enabled expected links' {
        $expected=@{
            'DC=corp,DC=lab'=@('LAB-Domain-Account-Policy','LAB-Security-Baseline')
            'OU=Computers,DC=corp,DC=lab'=@('LAB-Windows-Update')
            'OU=Staff,DC=corp,DC=lab'=@('LAB-Desktop-Restrictions','LAB-Drive-Finance','LAB-Drive-HR','LAB-Drive-IT','LAB-Printer-Deployment')
        }
        foreach ($target in $expected.Keys) {
            $links=(Get-GPInheritance -Target $target).GpoLinks
            foreach ($name in $expected[$target]) {
                @($links | Where-Object { $_.DisplayName -eq $name -and $_.Enabled }).Count | Should -Be 1
            }
        }
    }
}
