#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference='Stop'
$free=(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1KB
if ($free -lt 8GB) { throw 'Free at least 8 GiB RAM before starting the two-VM lab. Close other apps/VMs.' }
if ((Get-PSDrive H).Free -lt 35GB) { throw 'Keep at least 35 GiB free on H: for dynamic disk growth.' }
foreach ($name in @('DC01','CLIENT01')) {
    if ($PSCmdlet.ShouldProcess($name,'Start lab VM')) { Start-VM -Name $name }
}
