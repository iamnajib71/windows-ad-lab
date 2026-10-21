BeforeAll { Import-Module "$PSScriptRoot/../src/Lab.Image.psm1" -Force }
Describe 'Evaluation WIM selection' {
    It 'selects the actual downloaded Server Core display name rather than Desktop Experience' {
        $images=@(
            @{ImageIndex=1;ImageName='Windows Server 2022 Standard Evaluation'}
            @{ImageIndex=2;ImageName='Windows Server 2022 Standard Evaluation (Desktop Experience)'}
            @{ImageIndex=3;ImageName='Windows Server 2022 Datacenter Evaluation'}
        )
        (Get-LabImageSelection DC01 $images).ImageIndex | Should -Be 1
    }
    It 'selects only Windows 11 Enterprise Evaluation' {
        $images=@(@{ImageIndex=1;ImageName='Windows 11 Enterprise Evaluation'},@{ImageIndex=2;ImageName='Windows 11 Pro'})
        (Get-LabImageSelection CLIENT01 $images).ImageIndex | Should -Be 1
    }
    It 'rejects non-evaluation client media' {
        { Get-LabImageSelection CLIENT01 @(@{ImageIndex=1;ImageName='Windows 11 Enterprise'}) } | Should -Throw '*exactly one*'
    }
    It 'rejects duplicate matches before disk partitioning' {
        { Get-LabImageSelection DC01 @(@{ImageName='Windows Server 2022 Standard Evaluation'},@{ImageName='Windows Server 2022 Standard Evaluation'}) } | Should -Throw '*exactly one*'
    }
}
