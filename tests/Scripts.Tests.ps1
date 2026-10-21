BeforeAll { $root=Split-Path $PSScriptRoot -Parent }
Describe 'PowerShell entry point contracts' {
    It 'all operational scripts parse and expose WhatIf' {
        $scripts=Get-ChildItem "$root/scripts" -Filter *.ps1 -Recurse
        $scripts.Count | Should -BeGreaterThan 10
        foreach ($file in $scripts) {
            $tokens=$null; $errors=$null
            $ast=[System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
            @($errors).Count | Should -Be 0 -Because $file.Name
            $ast.ParamBlock.Attributes.Extent.Text -join ' ' | Should -Match 'SupportsShouldProcess' -Because $file.Name
        }
    }
    It 'keeps local secrets, instructions and large lab files ignored' {
        $ignore=Get-Content "$root/.gitignore"
        foreach ($entry in @('.env','AGENTS.md','CLAUDE.md','.lab/','.tools/','*.iso','*.vhd*')) { $ignore | Should -Contain $entry }
    }
}
