# Run manually as CORP\alex.morgan on CLIENT01 after changing its initial password.
BeforeAll {
    if ($env:COMPUTERNAME -ne 'CLIENT01' -or [Security.Principal.WindowsIdentity]::GetCurrent().Name -ne 'CORP\alex.morgan') {
        throw 'Acceptance requires the actual CLIENT01 / CORP\alex.morgan session.'
    }
}
Describe 'Real fictional staff client experience' {
    It 'is a corp.lab domain member' {
        $computer=Get-CimInstance Win32_ComputerSystem
        $computer.PartOfDomain | Should -BeTrue
        $computer.Domain | Should -Be 'corp.lab'
    }
    It 'has the effective desktop restriction' {
        (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name NoControlPanel).NoControlPanel | Should -Be 1
    }
    It 'requires SMB client signing and disables LLMNR' {
        (Get-SmbClientConfiguration).RequireSecuritySignature | Should -BeTrue
        (Get-ItemProperty 'HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient' -Name EnableMulticast).EnableMulticast | Should -Be 0
    }
    It 'maps Finance to F:' {
        (Get-SmbMapping -LocalPath 'F:').RemotePath | Should -Be '\\DC01\Finance'
    }
    It 'permits Finance and own home access while denying HR and another home' {
        Test-Path '\\DC01\Finance' | Should -BeTrue
        Test-Path '\\DC01\Homes\alex.morgan' | Should -BeTrue
        Test-Path '\\DC01\HR' -ErrorAction SilentlyContinue | Should -BeFalse
        Test-Path '\\DC01\Homes\jamie.chen' -ErrorAction SilentlyContinue | Should -BeFalse
    }
    It 'has the deployed shared virtual printer' {
        @(Get-Printer | Where-Object Name -eq '\\DC01\LAB-Printer').Count | Should -Be 1
    }
}
