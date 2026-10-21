#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param(
    [Parameter(Mandatory)][ValidateSet('DC01','CLIENT01')][string]$VMName,
    [Parameter(Mandatory)][string]$IsoPath,
    [Parameter(Mandatory)][securestring]$LocalPassword,
    [string]$LabRoot='H:\My Projects - IT\windows-ad-lab\.lab'
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\src\Lab.Image.psm1') -Force
$LabRoot=[IO.Path]::GetFullPath($LabRoot)
if ([IO.Path]::GetPathRoot($LabRoot) -eq 'C:\') { throw 'Use a data drive for all image and scratch files.' }
$vm=Get-VM -Name $VMName
if ($vm.State -ne 'Off') { throw 'VM must be powered off.' }
$vhdPath=Join-Path $LabRoot "$VMName\$VMName.vhdx"
$attached=@(Get-VMHardDiskDrive -VMName $VMName | Where-Object Path -eq $vhdPath)
if ($attached.Count -ne 1) { throw 'Expected the single lab OS disk at the specified path.' }
if (-not (Test-Path -LiteralPath $IsoPath)) { throw 'ISO is missing.' }
if (-not $PSCmdlet.ShouldProcess($vhdPath,'Apply evaluation Windows image only to an empty lab VHDX and configure local setup')) { return }
$diskImage=$null
$mounted=$false
try {
    $disk=Mount-VHD -Path $vhdPath -PassThru | Get-Disk
    $mounted=$true
    if ($disk.PartitionStyle -ne 'RAW' -or $disk.IsBoot -or $disk.IsSystem) { throw 'Refusing to change a nonempty or system disk.' }
    $diskImage=Mount-DiskImage -ImagePath (Resolve-Path -LiteralPath $IsoPath).Path -PassThru
    $isoVolume=$diskImage | Get-Volume
    $source="$($isoVolume.DriveLetter):\sources\install.wim"
    if (-not (Test-Path -LiteralPath $source)) { throw 'Expected install.wim in the official evaluation ISO.' }
    $images=@(Get-WindowsImage -ImagePath $source)
    try { $image=Get-LabImageSelection -VMName $VMName -Images $images }
    catch {
        $images | Select-Object ImageIndex,ImageName | Out-String | Write-Output
        throw 'Could not identify a unique requested evaluation image. No partition changes made.'
    }
    $disk=$disk | Initialize-Disk -PartitionStyle GPT -PassThru
    $efi=New-Partition -DiskNumber $disk.Number -Size 260MB -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' -AssignDriveLetter
    $null=$efi | Format-Volume -FileSystem FAT32 -NewFileSystemLabel System -Confirm:$false
    $null=New-Partition -DiskNumber $disk.Number -Size 16MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
    $os=New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter
    $null=$os | Format-Volume -FileSystem NTFS -NewFileSystemLabel $VMName -Confirm:$false
    $destination="$($os.DriveLetter):\"
    $scratch=Join-Path $LabRoot 'scratch'
    $null=New-Item -ItemType Directory -Path $scratch -Force
    $log=Join-Path $LabRoot "$VMName-dism.log"
    & dism.exe /Apply-Image "/ImageFile:$source" "/Index:$($image.ImageIndex)" "/ApplyDir:$destination" "/ScratchDir:$scratch" "/LogPath:$log"
    if ($LASTEXITCODE -ne 0) { throw "DISM failed: $LASTEXITCODE. The partial lab disk needs inspection." }
    & bcdboot.exe "${destination}Windows" /s "$($efi.DriveLetter):" /f UEFI
    if ($LASTEXITCODE -ne 0) { throw 'BCDBoot failed.' }
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
    # Encoded setup passwords are still secrets. This file stays only inside the ignored VHDX.
    $unattend=@"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
 <settings pass="specialize">
  <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
   <ComputerName>$VMName</ComputerName><TimeZone>AUS Eastern Standard Time</TimeZone><RegisteredOwner>Lab</RegisteredOwner>
  </component>
 </settings>
 <settings pass="oobeSystem">
  <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
   <InputLocale>en-US</InputLocale><SystemLocale>en-US</SystemLocale><UILanguage>en-US</UILanguage><UserLocale>en-AU</UserLocale>
  </component>
  <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
   <OOBE><HideEULAPage>true</HideEULAPage><HideOnlineAccountScreens>true</HideOnlineAccountScreens><HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE><ProtectYourPC>1</ProtectYourPC></OOBE>
   <UserAccounts>$accounts</UserAccounts>
  </component>
 </settings>
</unattend>
"@
    $panther=Join-Path $destination 'Windows\Panther'
    $null=New-Item -ItemType Directory -Path $panther -Force
    $unattend | Set-Content -LiteralPath (Join-Path $panther 'Unattend.xml') -Encoding UTF8
    $unattend=$null; $accounts=$null; $encodedAdmin=$null; $encodedLocal=$null
    $image | Select-Object ImageIndex,ImageName
} finally {
    if ($diskImage) { Dismount-DiskImage -ImagePath $diskImage.ImagePath | Out-Null }
    if ($mounted) { Dismount-VHD -Path $vhdPath }
}
Set-VMFirmware -VMName $VMName -FirstBootDevice $attached[0]
