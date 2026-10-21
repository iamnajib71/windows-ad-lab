#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param([ValidateSet('DC01','CLIENT01')][string[]]$VMName=@('DC01','CLIENT01'))
$ErrorActionPreference='Stop'
$free=(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1KB
$pending=@(Get-VM -Name $VMName | Where-Object State -eq 'Off')
$startup=($pending | Measure-Object MemoryStartup -Sum).Sum
$required=2GB+$startup
if ($free -lt $required) { throw "Need $([math]::Ceiling($required/1GB)) GiB free RAM for the requested stopped VMs plus host headroom." }
if ((Get-PSDrive H).Free -lt 35GB) { throw 'Keep at least 35 GiB free on H: for dynamic disk growth.' }
foreach ($vm in $pending) {
    if ($PSCmdlet.ShouldProcess($vm.Name,'Start lab VM')) { Start-VM -VM $vm }
}
