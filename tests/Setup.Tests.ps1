BeforeAll {
    Import-Module "$PSScriptRoot/../src/Lab.Setup.psm1" -Force
    $testPassword=[securestring]::new()
    $testValue=[guid]::NewGuid().ToString('N')
    foreach ($letter in $testValue.ToCharArray()) { $testPassword.AppendChar($letter) }
}
Describe 'VM-only Windows Setup answer file' {
    It 'targets only guest disk 0 and partition 3, without host paths or product keys' {
        $xml=Get-LabSetupAnswerFile DC01 $testPassword
        $ns=[Xml.XmlNamespaceManager]::new($xml.NameTable)
        $ns.AddNamespace('u','urn:schemas-microsoft-com:unattend')
        $xml.SelectSingleNode('//u:InstallTo/u:DiskID',$ns).InnerText | Should -Be '0'
        $xml.SelectSingleNode('//u:InstallTo/u:PartitionID',$ns).InnerText | Should -Be '3'
        $xml.SelectNodes('//u:ProductKey',$ns).Count | Should -Be 0
        $xml.OuterXml | Should -Not -Match 'H:|bcdboot|diskpart'
        $xml.OuterXml | Should -Not -Match ([regex]::Escape($testValue))
        $xml.SelectSingleNode('//u:ComputerName',$ns).InnerText | Should -Be 'DC01'
    }
    It 'uses local LabAdmin for the client and encoded password fields' {
        $xml=Get-LabSetupAnswerFile CLIENT01 $testPassword
        $ns=[Xml.XmlNamespaceManager]::new($xml.NameTable)
        $ns.AddNamespace('u','urn:schemas-microsoft-com:unattend')
        $xml.SelectSingleNode('//u:LocalAccount/u:Name',$ns).InnerText | Should -Be LabAdmin
        $xml.SelectSingleNode('//u:Password/u:PlainText',$ns).InnerText | Should -Be 'false'
        $xml.SelectSingleNode('//u:ComputerName',$ns).InnerText | Should -Be CLIENT01
    }
}
