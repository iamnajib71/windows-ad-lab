#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param([ValidatePattern('^[D-Z]$')][string]$DriveLetter='E')
$ErrorActionPreference='Stop'
if ($env:COMPUTERNAME -ne 'DC01') { throw 'Run inside DC01 only.' }
if (Get-Volume -DriveLetter $DriveLetter -ErrorAction SilentlyContinue) { throw 'Drive letter already used. Select a free drive letter.' }
$disks=@(Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -and $_.Size -eq 40GB -and -not $_.IsBoot -and -not $_.IsSystem })
if ($disks.Count -ne 1) { throw 'Expected exactly one uninitialised 40 GiB lab backup disk. Inspect Get-Disk first.' }
if ($PSCmdlet.ShouldProcess("Disk $($disks[0].Number)",'Initialise only the raw 40 GiB backup disk and format NTFS')) {
    $disk=$disks[0] | Initialize-Disk -PartitionStyle GPT -PassThru
    $partition=$disk | New-Partition -UseMaximumSize -DriveLetter $DriveLetter
    $null=$partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel LAB-Backup -Confirm:$false
}
