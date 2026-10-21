#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param([ValidateSet('DC01','CLIENT01')][string[]]$VMName=@('DC01','CLIENT01'),[switch]$BootSetup)
$ErrorActionPreference='Stop'
$free=(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1KB
$pending=@(Get-VM -Name $VMName | Where-Object State -eq 'Off')
$startup=($pending | Measure-Object MemoryStartup -Sum).Sum
$required=2GB+$startup
if ($free -lt $required) { throw "Need $([math]::Ceiling($required/1GB)) GiB free RAM for the requested stopped VMs plus host headroom." }
if ((Get-PSDrive H).Free -lt 35GB) { throw 'Keep at least 35 GiB free on H: for dynamic disk growth.' }
foreach ($vm in $pending) {
    if ($PSCmdlet.ShouldProcess($vm.Name,'Start lab VM')) {
        Start-VM -VM $vm
        if ($BootSetup) {
            Start-Sleep -Seconds 2
            $system=Get-CimInstance -Namespace root/virtualization/v2 -ClassName Msvm_ComputerSystem -Filter "Name='$($vm.Id)'"
            $keyboard=@(Get-CimAssociatedInstance -InputObject $system -ResultClassName Msvm_Keyboard)
            if ($keyboard.Count -ne 1) { throw 'VM started; press a boot key manually in VMConnect. No unique virtual keyboard was returned.' }
            $result=Invoke-CimMethod -InputObject $keyboard[0] -MethodName TypeKey -Arguments @{keyCode=[uint32]32}
            if ($result.ReturnValue -ne 0) { throw "VM started, but the virtual boot key failed: $($result.ReturnValue). Use VMConnect." }
        }
    }
}
