#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param([string]$LabRoot='H:\My Projects - IT\windows-ad-lab\.lab')
$ErrorActionPreference='Stop'
$attached=@(Get-VMHardDiskDrive -VMName DC01 | Where-Object { $_.Path -and (Split-Path $_.Path -Leaf) -eq 'DC01-backup.vhdx' })
if ($attached.Count) { throw 'DC01 already has a lab backup disk attached; inspect its current storage path rather than creating another.' }
$path=Join-Path ([IO.Path]::GetFullPath($LabRoot)) 'DC01\DC01-backup.vhdx'
if ([IO.Path]::GetPathRoot($path) -eq 'C:\') { throw 'Store the backup VHDX on a data drive.' }
if (Test-Path -LiteralPath $path) { throw 'Backup disk already exists; inspect rather than overwrite.' }
if ($PSCmdlet.ShouldProcess($path,'Create and attach 40 GiB dynamic backup disk to DC01')) {
    $null=New-VHD -Path $path -SizeBytes 40GB -Dynamic
    Add-VMHardDiskDrive -VMName DC01 -Path $path
}
