#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param(
    [string]$DestinationRoot='E:\WindowsADLab',
    [string]$SourceRoot='H:\My Projects - IT\windows-ad-lab\.lab',
    [ValidateSet('DC01','CLIENT01')][string[]]$VMName=@('DC01','CLIENT01')
)
$ErrorActionPreference='Stop'
$DestinationRoot=[IO.Path]::GetFullPath($DestinationRoot).TrimEnd('\')
$SourceRoot=[IO.Path]::GetFullPath($SourceRoot).TrimEnd('\')
if ($DestinationRoot -notmatch '^[D-Z]:\\.+' -or $DestinationRoot -eq $SourceRoot) { throw 'Choose a dedicated directory on a local data volume.' }
$plan=@()
$bytes=0L
foreach ($name in $VMName) {
    $vm=Get-VM -Name $name
    if ($vm.State -notin @('Off','Saved')) { throw "Shut down or save $name before moving its storage." }
    $expectedSource=(Join-Path $SourceRoot $name)+'\'
    $destination=Join-Path $DestinationRoot $name
    if (Test-Path -LiteralPath $destination) { throw "Destination already exists: $destination. Inspect any previous move; no overwrite is allowed." }
    foreach ($disk in @(Get-VMHardDiskDrive -VM $vm)) {
        if (-not $disk.Path -or -not ([IO.Path]::GetFullPath($disk.Path)).StartsWith($expectedSource,[StringComparison]::OrdinalIgnoreCase)) { throw "Unexpected virtual disk path for $name." }
        $bytes+=(Get-Item -LiteralPath $disk.Path).Length
    }
    $plan+=[pscustomobject]@{VM=$vm;Destination=$destination}
}
$drive=Get-PSDrive -Name $DestinationRoot.Substring(0,1)
if ($drive.Free -lt $bytes+40GB) { throw 'Destination needs room for all current virtual disks plus 40 GiB growth headroom.' }
foreach ($item in $plan) {
    if ($PSCmdlet.ShouldProcess($item.Destination,"Move all $($item.VM.Name) storage with Hyper-V")) {
        Move-VMStorage -VM $item.VM -DestinationStoragePath $item.Destination
        Set-VM -VM $item.VM -SnapshotFileLocation $item.Destination -SmartPagingFilePath $item.Destination
        foreach ($disk in @(Get-VMHardDiskDrive -VMName $item.VM.Name)) {
            if (-not ([IO.Path]::GetFullPath($disk.Path)).StartsWith($item.Destination+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Hyper-V storage verification failed; leave the VM off and inspect.' }
        }
        Get-VM -Name $item.VM.Name | Select-Object Name,State,Path,SnapshotFileLocation,SmartPagingFilePath
        Get-VMHardDiskDrive -VMName $item.VM.Name | Select-Object VMName,Path
    }
}
