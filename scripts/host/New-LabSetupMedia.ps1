#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param(
    [Parameter(Mandatory)][ValidateSet('DC01','CLIENT01')][string]$VMName,
    [Parameter(Mandatory)][securestring]$LocalPassword,
    [string]$LabRoot='H:\My Projects - IT\windows-ad-lab\.lab'
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\src\Lab.Setup.psm1') -Force
$LabRoot=[IO.Path]::GetFullPath($LabRoot)
if ([IO.Path]::GetPathRoot($LabRoot) -eq 'C:\') { throw 'Setup media must stay on a data drive.' }
$vm=Get-VM -Name $VMName
if ($vm.State -ne 'Off') { throw 'Power off the lab VM before attaching setup media.' }
$disks=@(Get-VMHardDiskDrive -VMName $VMName)
$expected=Join-Path $LabRoot "$VMName\$VMName.vhdx"
if ($disks.Count -ne 1 -or $disks[0].Path -ne $expected -or $disks[0].ControllerType -ne 'SCSI' -or $disks[0].ControllerNumber -ne 0 -or $disks[0].ControllerLocation -ne 0) {
    throw 'Setup requires exactly the single lab OS VHDX at SCSI 0:0. Do not attach host disks or the backup disk during OS installation.'
}
if ((Get-VHD -Path $expected).Attached) { throw 'Detach the offline lab VHD from the host before starting Windows Setup.' }
$isoName=if ($VMName -eq 'DC01') { 'server-2022-eval.iso' } else { 'windows-11-enterprise-eval.iso' }
$osIso=Join-Path $LabRoot "iso\$isoName"
if (-not (Test-Path $osIso)) { throw 'Official evaluation ISO missing.' }
if (-not $PSCmdlet.ShouldProcess($VMName,'Create private unattended media; Windows Setup inside this VM will replace only its virtual OS disk')) { return }
$folder=Join-Path $LabRoot "setup\$VMName"
$null=New-Item -ItemType Directory -Path $folder -Force
$acl=Get-Acl (Join-Path $LabRoot 'credentials')
Set-Acl -LiteralPath (Split-Path $folder -Parent) -AclObject $acl
$answer=Get-LabSetupAnswerFile -VMName $VMName -LocalPassword $LocalPassword
$answer.Save((Join-Path $folder 'Autounattend.xml'))
if (-not ('LabIsoStream' -as [type])) {
    $env:TEMP=Join-Path $LabRoot 'scratch'
    $env:TMP=$env:TEMP
    $null=New-Item -ItemType Directory -Path $env:TEMP -Force
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public static class LabIsoStream {
 public static void Save(object source, string path) {
  IStream stream=(IStream)source;
  IntPtr count=Marshal.AllocHGlobal(4);
  try {
   using (FileStream output=new FileStream(path,FileMode.Create,FileAccess.Write)) {
    byte[] buffer=new byte[65536];
    while(true) {
     stream.Read(buffer,buffer.Length,count);
     int length=Marshal.ReadInt32(count);
     if(length==0) break;
     output.Write(buffer,0,length);
    }
   }
  } finally { Marshal.FreeHGlobal(count); }
 }
}
'@
}
$filesystem=New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$filesystem.ChooseImageDefaultsForMediaType(12)
$filesystem.FileSystemsToCreate=3
$filesystem.VolumeName="${VMName}_SETUP"
$filesystem.Root.AddTree($folder,$false)
$result=$filesystem.CreateResultImage()
$setupIso=Join-Path (Split-Path $folder -Parent) "$VMName-setup.iso"
[LabIsoStream]::Save($result.ImageStream,$setupIso)
$drives=@(Get-VMDvdDrive -VMName $VMName)
$primary=$drives | Where-Object Path -eq $osIso | Select-Object -First 1
if (-not $primary) { throw 'Expected the official OS ISO already attached to this VM.' }
$secondary=$drives | Where-Object Path -eq $setupIso
if (-not $secondary) { Add-VMDvdDrive -VMName $VMName -Path $setupIso }
Set-VMFirmware -VMName $VMName -FirstBootDevice $primary
[pscustomobject]@{VM=$VMName;OSISO=$osIso;SetupISO=$setupIso;Target='Guest virtual disk 0 only; no host disk mounted or formatted'}
