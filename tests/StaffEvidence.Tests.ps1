BeforeAll {
    $staffEvidenceScript=Join-Path $PSScriptRoot '..\scripts\client\Invoke-LabStaffEvidence.ps1'
}
Describe 'Staff evidence execution boundary' {
    It 'rejects another computer before creating evidence or changing mappings' {
        $previousName=$env:COMPUTERNAME
        Mock New-Item { throw 'Unexpected filesystem write.' }
        Mock Remove-SmbMapping { throw 'Unexpected mapping change.' }
        try {
            $env:COMPUTERNAME='OUTSIDE-LAB'
            { & $staffEvidenceScript -Step Ticket02Before -OutputDirectory (Join-Path $TestDrive 'evidence') } | Should -Throw '*interactive session*'
            Should -Invoke New-Item -Times 0
            Should -Invoke Remove-SmbMapping -Times 0
        } finally { $env:COMPUTERNAME=$previousName }
    }
}
