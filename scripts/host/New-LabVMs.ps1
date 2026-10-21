#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$LabRoot='H:\My Projects - IT\windows-ad-lab\.lab',
    [string]$ServerIso,
    [string]$ClientIso
)
$ErrorActionPreference='Stop'
Import-Module Hyper-V -ErrorAction Stop
$LabRoot=[IO.Path]::GetFullPath($LabRoot)
if ([IO.Path]::GetPathRoot($LabRoot) -eq 'C:\') { throw 'Use a data drive, not C:.' }
foreach ($iso in @($ServerIso,$ClientIso)) {
    if (-not $iso -or -not (Test-Path -LiteralPath $iso -PathType Leaf)) { throw 'Both evaluation ISO paths are required.' }
}
$switchName='WindowsADLab-Internal'
$existing=Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue
if ($existing -and $existing.SwitchType -ne 'Internal') { throw 'Existing lab switch has the wrong type.' }
$conflicts=@(Get-NetNat -ErrorAction SilentlyContinue | Where-Object Name -ne 'WindowsADLab-NAT')
if ($conflicts.Count) { throw 'Another WinNAT exists. Resolve address-space compatibility manually before creating this lab NAT.' }
if ($PSCmdlet.ShouldProcess($LabRoot,'Create isolated lab switch, NAT and powered-off Gen 2 VMs on data drive')) {
    $null=New-Item -ItemType Directory -Path $LabRoot -Force
    if (-not $existing) { $null=New-VMSwitch -Name $switchName -SwitchType Internal }
    $adapter=Get-NetAdapter -Name "vEthernet ($switchName)"
    if (-not (Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object IPAddress -eq '192.168.77.1')) {
        $null=New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress '192.168.77.1' -PrefixLength 24
    }
    if (-not (Get-NetNat -Name 'WindowsADLab-NAT' -ErrorAction SilentlyContinue)) {
        $null=New-NetNat -Name 'WindowsADLab-NAT' -InternalIPInterfaceAddressPrefix '192.168.77.0/24'
    }
    foreach ($spec in @(@{Name='DC01';Memory=2GB;Max=4GB;Disk=60GB;Iso=$ServerIso},@{Name='CLIENT01';Memory=4GB;Max=6GB;Disk=80GB;Iso=$ClientIso})) {
        $vmPath=Join-Path $LabRoot $spec.Name
        if (Get-VM -Name $spec.Name -ErrorAction SilentlyContinue) { throw "VM $($spec.Name) already exists. Review it; no overwrite is allowed." }
        $null=New-Item -ItemType Directory -Path $vmPath -Force
        $vm=New-VM -Name $spec.Name -Generation 2 -MemoryStartupBytes $spec.Memory -NewVHDPath (Join-Path $vmPath "$($spec.Name).vhdx") -NewVHDSizeBytes $spec.Disk -SwitchName $switchName -Path $vmPath
        Set-VM -VM $vm -ProcessorCount 2 -AutomaticCheckpointsEnabled $false -CheckpointType ProductionOnly -AutomaticStartAction Nothing -AutomaticStopAction ShutDown
        Set-VM -VM $vm -SnapshotFileLocation $vmPath -SmartPagingFilePath $vmPath
        Set-VMMemory -VM $vm -DynamicMemoryEnabled $true -MinimumBytes $spec.Memory -MaximumBytes $spec.Max
        Set-VMFirmware -VM $vm -EnableSecureBoot On -SecureBootTemplate MicrosoftWindows
        Set-VMKeyProtector -VM $vm -NewLocalKeyProtector
        Enable-VMTPM -VM $vm
        Add-VMDvdDrive -VM $vm -Path $spec.Iso
        Set-VMFirmware -VM $vm -FirstBootDevice (Get-VMDvdDrive -VM $vm)
    }
    Get-VM -Name DC01,CLIENT01 | Select-Object Name,State,Path,SnapshotFileLocation,SmartPagingFilePath
}
