function Get-LabSetupAnswerFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('DC01','CLIENT01')][string]$VMName,
        [Parameter(Mandatory)][securestring]$LocalPassword
    )
    $pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($LocalPassword)
    try { $plain=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    $encodedAdmin=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($plain+'AdministratorPassword'))
    $encodedLocal=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($plain+'Password'))
    $plain=$null
    $accounts=if ($VMName -eq 'DC01') {
        "<AdministratorPassword><Value>$encodedAdmin</Value><PlainText>false</PlainText></AdministratorPassword>"
    } else {
        "<LocalAccounts><LocalAccount wcm:action=`"add`"><Password><Value>$encodedLocal</Value><PlainText>false</PlainText></Password><Name>LabAdmin</Name><DisplayName>Lab Administrator</DisplayName><Group>Administrators</Group></LocalAccount></LocalAccounts>"
    }
    [xml]@"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
 <settings pass="windowsPE">
  <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
   <SetupUILanguage><UILanguage>en-US</UILanguage></SetupUILanguage><InputLocale>en-US</InputLocale><SystemLocale>en-US</SystemLocale><UILanguage>en-US</UILanguage><UserLocale>en-AU</UserLocale>
  </component>
  <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
   <DiskConfiguration><Disk wcm:action="add"><DiskID>0</DiskID><WillWipeDisk>true</WillWipeDisk>
    <CreatePartitions>
     <CreatePartition wcm:action="add"><Order>1</Order><Type>EFI</Type><Size>260</Size></CreatePartition>
     <CreatePartition wcm:action="add"><Order>2</Order><Type>MSR</Type><Size>16</Size></CreatePartition>
     <CreatePartition wcm:action="add"><Order>3</Order><Type>Primary</Type><Extend>true</Extend></CreatePartition>
    </CreatePartitions>
    <ModifyPartitions>
     <ModifyPartition wcm:action="add"><Order>1</Order><PartitionID>1</PartitionID><Format>FAT32</Format><Label>System</Label></ModifyPartition>
     <ModifyPartition wcm:action="add"><Order>2</Order><PartitionID>3</PartitionID><Format>NTFS</Format><Label>$VMName</Label><Letter>C</Letter></ModifyPartition>
    </ModifyPartitions>
   </Disk><WillShowUI>OnError</WillShowUI></DiskConfiguration>
   <ImageInstall><OSImage><InstallFrom><MetaData wcm:action="add"><Key>/IMAGE/INDEX</Key><Value>1</Value></MetaData></InstallFrom><InstallTo><DiskID>0</DiskID><PartitionID>3</PartitionID></InstallTo><WillShowUI>OnError</WillShowUI></OSImage></ImageInstall>
   <UserData><AcceptEula>true</AcceptEula><FullName>Lab</FullName><Organization>Fictional Lab</Organization></UserData>
  </component>
 </settings>
 <settings pass="specialize">
  <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"><ComputerName>$VMName</ComputerName><TimeZone>AUS Eastern Standard Time</TimeZone><RegisteredOwner>Lab</RegisteredOwner></component>
 </settings>
 <settings pass="oobeSystem">
  <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"><InputLocale>en-US</InputLocale><SystemLocale>en-US</SystemLocale><UILanguage>en-US</UILanguage><UserLocale>en-AU</UserLocale></component>
  <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
   <OOBE><HideEULAPage>true</HideEULAPage><HideOnlineAccountScreens>true</HideOnlineAccountScreens><HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE><ProtectYourPC>1</ProtectYourPC></OOBE>
   <UserAccounts>$accounts</UserAccounts>
  </component>
 </settings>
</unattend>
"@
}
Export-ModuleMember -Function Get-LabSetupAnswerFile
