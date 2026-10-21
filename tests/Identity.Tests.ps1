BeforeAll {
    Import-Module "$PSScriptRoot/../src/Lab.Identity.psm1" -Force
    # Domain cmdlet stubs only define signatures so Pester can mock on a non-domain runner.
    # They throw if accidentally executed: no simulated result can escape as lab evidence.
    InModuleScope Lab.Identity {
        function script:Get-ADDomain { param($Server) throw 'Unmocked AD command' }
        function script:Get-ADUser { param($Identity,$Server,$Properties,$Filter,$SearchBase) throw 'Unmocked AD command' }
        function script:Get-ADGroup { param($Identity,$Server) throw 'Unmocked AD command' }
        function script:Get-ADOrganizationalUnit { param($Identity,$Server) throw 'Unmocked AD command' }
        function script:New-ADUser { param($Name,$SamAccountName,$GivenName,$Surname,$DisplayName,$Department,$Title,$UserPrincipalName,$EmailAddress,$Path,$HomeDirectory,$HomeDrive,$AccountPassword,$Enabled,$ChangePasswordAtLogon,$Server) throw 'Unmocked AD command' }
        function script:Add-ADGroupMember { param($Identity,$Members,$Server) throw 'Unmocked AD command' }
        function script:Enable-ADAccount { param($Identity,$Server) throw 'Unmocked AD command' }
        function script:Disable-ADAccount { param($Identity,$Server) throw 'Unmocked AD command' }
        function script:Set-ADAccountPassword { param($Identity,[switch]$Reset,$NewPassword,$Server) throw 'Unmocked AD command' }
        function script:Set-ADUser { param($Identity,$ChangePasswordAtLogon,$Server) throw 'Unmocked AD command' }
        function script:Unlock-ADAccount { param($Identity,$Server) throw 'Unmocked AD command' }
        function script:Remove-ADGroupMember { [CmdletBinding(SupportsShouldProcess)]param($Identity,$Members,$Server) throw 'Unmocked AD command' }
        function script:Move-ADObject { param($Identity,$TargetPath,$Server) throw 'Unmocked AD command' }
    }
}

Describe 'CSV onboarding planning (no domain)' {
    BeforeEach { $csv=Join-Path $TestDrive 'users.csv' }
    It 'maps fictional sample users to OU, group, private home and reserved email' {
        $plan=@(Get-LabOnboardingPlan "$PSScriptRoot/../data/onboarding.csv")
        $plan.Count | Should -Be 3
        $plan[0].Path | Should -Be 'OU=Finance,OU=Staff,DC=corp,DC=lab'
        $plan[0].Group | Should -Be 'GG_Finance'
        $plan[0].HomeDirectory | Should -Be '\\DC01\Homes\alex.morgan'
        $plan[0].EmailAddress | Should -Be 'alex.morgan@corp.example.invalid'
    }
    It 'rejects duplicates before returning any plan' {
        "SamAccountName,GivenName,Surname,Department,Title`nalex,Alex,Test,IT,Analyst`nalex,Alex,Test,IT,Analyst" | Set-Content $csv
        { Get-LabOnboardingPlan $csv } | Should -Throw '*Duplicate*'
    }
    It 'rejects path traversal and filter injection' {
        "SamAccountName,GivenName,Surname,Department,Title`n../bad,Alex,Test,IT,Analyst" | Set-Content $csv
        { Get-LabOnboardingPlan $csv } | Should -Throw '*Invalid*'
    }
    It 'rejects unknown departments' {
        "SamAccountName,GivenName,Surname,Department,Title`nalex,Alex,Test,Executive,Analyst" | Set-Content $csv
        { Get-LabOnboardingPlan $csv } | Should -Throw '*department*'
    }
    It 'rejects missing columns' {
        "SamAccountName,GivenName`nalex,Alex" | Set-Content $csv
        { Get-LabOnboardingPlan $csv } | Should -Throw '*Missing*'
    }
    It 'rejects an empty CSV' {
        'SamAccountName,GivenName,Surname,Department,Title' | Set-Content $csv
        { Get-LabOnboardingPlan $csv } | Should -Throw '*empty*'
    }
}

Describe 'Identity safety and orchestration (mocked AD)' {
    BeforeEach {
        Mock Get-ADDomain -ModuleName Lab.Identity { @{DNSRoot='corp.lab'} }
        Mock Get-ADGroup -ModuleName Lab.Identity { @{SID=@{Value='S-1-5-21-1-2-3-1101'}} }
        Mock Get-ADOrganizationalUnit -ModuleName Lab.Identity { @{Name='Finance'} }
        Mock Get-ADUser -ModuleName Lab.Identity {
            if ($Filter) { return }
            [pscustomobject]@{SamAccountName='alex.morgan';DistinguishedName='CN=Alex Morgan,OU=Finance,OU=Staff,DC=corp,DC=lab';MemberOf=@('CN=GG_Finance,OU=Finance,OU=Groups,DC=corp,DC=lab');SID=@{Value='S-1-5-21-1-2-3-1100'}}
        }
        Mock New-ADUser -ModuleName Lab.Identity {}
        Mock Add-ADGroupMember -ModuleName Lab.Identity {}
        Mock Enable-ADAccount -ModuleName Lab.Identity {}
        Mock Disable-ADAccount -ModuleName Lab.Identity {}
        Mock Set-ADAccountPassword -ModuleName Lab.Identity {}
        Mock Set-ADUser -ModuleName Lab.Identity {}
        Mock Unlock-ADAccount -ModuleName Lab.Identity {}
        Mock Remove-ADGroupMember -ModuleName Lab.Identity {}
        Mock Move-ADObject -ModuleName Lab.Identity {}
        $password=[securestring]::new()
        $password.AppendChar('x') # Never used against a domain.
    }
    It 'WhatIf onboarding does not create users or home folders' {
        $homePath=Join-Path $TestDrive 'homes'
        Invoke-LabOnboarding -CsvPath "$PSScriptRoot/../data/onboarding.csv" -InitialPassword $password -HomeRoot $homePath -WhatIf
        Should -Invoke New-ADUser -ModuleName Lab.Identity -Times 0 -Exactly
        Should -Invoke Add-ADGroupMember -ModuleName Lab.Identity -Times 0 -Exactly
        Test-Path $homePath | Should -BeFalse
    }
    It 'rejects an existing user before creating any accounts' {
        Mock Get-ADUser -ModuleName Lab.Identity { @{SamAccountName='existing'} } -ParameterFilter { $Filter }
        { Invoke-LabOnboarding -CsvPath "$PSScriptRoot/../data/onboarding.csv" -InitialPassword $password -HomeRoot $TestDrive } | Should -Throw '*exists*'
        Should -Invoke New-ADUser -ModuleName Lab.Identity -Times 0 -Exactly
    }
    It 'creates disabled accounts and enables them only after home ACL and membership succeed' {
        Mock New-Item -ModuleName Lab.Identity {}
        Mock Set-Acl -ModuleName Lab.Identity {}
        $result=@(Invoke-LabOnboarding -CsvPath "$PSScriptRoot/../data/onboarding.csv" -InitialPassword $password -HomeRoot (Join-Path $TestDrive 'homes'))
        $result.Count | Should -Be 3
        Should -Invoke New-ADUser -ModuleName Lab.Identity -Times 3 -Exactly -ParameterFilter { -not $Enabled -and $ChangePasswordAtLogon -and $HomeDrive -eq 'H:' -and $EmailAddress -like '*@corp.example.invalid' }
        Should -Invoke Set-Acl -ModuleName Lab.Identity -Times 3 -Exactly
        Should -Invoke Enable-ADAccount -ModuleName Lab.Identity -Times 3 -Exactly
        Should -Invoke Set-ADUser -ModuleName Lab.Identity -Times 3 -Exactly -ParameterFilter { $ChangePasswordAtLogon -eq $true }
    }
    It 'keeps partial onboarding disabled if home ACL configuration fails' {
        Mock New-Item -ModuleName Lab.Identity {}
        Mock Set-Acl -ModuleName Lab.Identity { throw 'ACL failure' }
        { Invoke-LabOnboarding -CsvPath "$PSScriptRoot/../data/onboarding.csv" -InitialPassword $password -HomeRoot (Join-Path $TestDrive 'homes') } | Should -Throw '*ACL failure*'
        Should -Invoke Disable-ADAccount -ModuleName Lab.Identity -Times 1 -Exactly
        Should -Invoke Enable-ADAccount -ModuleName Lab.Identity -Times 0 -Exactly
    }
    It 'refuses a different domain' {
        Mock Get-ADDomain -ModuleName Lab.Identity { @{DNSRoot='production.example'} }
        { Unlock-LabUser alex.morgan } | Should -Throw '*outside*'
        Should -Invoke Unlock-ADAccount -ModuleName Lab.Identity -Times 0 -Exactly
    }
    It 'refuses an admin outside Staff OU' {
        Mock Get-ADUser -ModuleName Lab.Identity { @{DistinguishedName='CN=Admin,OU=Admins,DC=corp,DC=lab';MemberOf=@()} }
        { Disable-LabUser admin -Confirm:$false } | Should -Throw '*Only Staff*'
        Should -Invoke Disable-ADAccount -ModuleName Lab.Identity -Times 0 -Exactly
    }
    It 'WhatIf reset does not change a password or flags' {
        Reset-LabPassword alex.morgan $password -WhatIf
        Should -Invoke Set-ADAccountPassword -ModuleName Lab.Identity -Times 0 -Exactly
        Should -Invoke Set-ADUser -ModuleName Lab.Identity -Times 0 -Exactly
    }
    It 'reset requires password change at next sign-in' {
        Reset-LabPassword alex.morgan $password
        Should -Invoke Set-ADAccountPassword -ModuleName Lab.Identity -Times 1 -Exactly -ParameterFilter { $Reset -and $NewPassword -eq $password }
        Should -Invoke Set-ADUser -ModuleName Lab.Identity -Times 1 -Exactly -ParameterFilter { $ChangePasswordAtLogon -eq $true }
    }
    It 'WhatIf unlock does not unlock' {
        Unlock-LabUser alex.morgan -WhatIf
        Should -Invoke Unlock-ADAccount -ModuleName Lab.Identity -Times 0 -Exactly
    }
    It 'unlocks the lab account' {
        Unlock-LabUser alex.morgan
        Should -Invoke Unlock-ADAccount -ModuleName Lab.Identity -Times 1 -Exactly
    }
    It 'WhatIf leaver does not disable, strip groups or move' {
        Disable-LabUser alex.morgan -WhatIf
        Should -Invoke Disable-ADAccount -ModuleName Lab.Identity -Times 0 -Exactly
        Should -Invoke Remove-ADGroupMember -ModuleName Lab.Identity -Times 0 -Exactly
        Should -Invoke Move-ADObject -ModuleName Lab.Identity -Times 0 -Exactly
    }
    It 'disables leaver, removes direct memberships and moves to Disabled' {
        Disable-LabUser alex.morgan -Confirm:$false
        Should -Invoke Disable-ADAccount -ModuleName Lab.Identity -Times 1 -Exactly
        Should -Invoke Remove-ADGroupMember -ModuleName Lab.Identity -Times 1 -Exactly
        Should -Invoke Move-ADObject -ModuleName Lab.Identity -Times 1 -Exactly -ParameterFilter { $TargetPath -eq 'OU=Disabled,DC=corp,DC=lab' }
    }
    It 'WhatIf bulk group change does not alter memberships' {
        Update-LabGroupMembership "$PSScriptRoot/../data/group-changes.csv" -WhatIf
        Should -Invoke Add-ADGroupMember -ModuleName Lab.Identity -Times 0 -Exactly
        Should -Invoke Remove-ADGroupMember -ModuleName Lab.Identity -Times 0 -Exactly
    }
    It 'prevalidates entire bulk CSV before changing anything' {
        $csv=Join-Path $TestDrive 'bad-groups.csv'
        "SamAccountName,Group,Action`nalex.morgan,GG_Finance,Add`nalex.morgan,Domain Admins,Add" | Set-Content $csv
        { Update-LabGroupMembership $csv } | Should -Throw '*Invalid*'
        Should -Invoke Add-ADGroupMember -ModuleName Lab.Identity -Times 0 -Exactly
    }
    It 'reports old and never-used old accounts but excludes new and recently used accounts' {
        Mock Get-ADUser -ModuleName Lab.Identity {
            @(
                [pscustomobject]@{SamAccountName='old';Enabled=$true;LastLogonDate=(Get-Date).AddDays(-120);whenCreated=(Get-Date).AddDays(-180)}
                [pscustomobject]@{SamAccountName='never';Enabled=$false;LastLogonDate=$null;whenCreated=(Get-Date).AddDays(-120)}
                [pscustomobject]@{SamAccountName='new';Enabled=$true;LastLogonDate=$null;whenCreated=(Get-Date)}
                [pscustomobject]@{SamAccountName='recent';Enabled=$true;LastLogonDate=(Get-Date);whenCreated=(Get-Date).AddDays(-180)}
            )
        }
        $output=Join-Path $TestDrive 'stale.csv'
        $result=@(Get-LabStaleAccount -InactiveDays 90 -OutputPath $output -WhatIf)
        $result.SamAccountName | Should -Be @('old','never')
        Test-Path $output | Should -BeFalse
        $null=Get-LabStaleAccount -InactiveDays 90 -OutputPath $output
        @(Import-Csv $output).Count | Should -Be 2
    }
}
