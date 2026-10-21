#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference='Stop'
if ($env:COMPUTERNAME -ne 'CLIENT01') { throw 'Run in CLIENT01 only.' }
foreach ($name in @('Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0','Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0','Rsat.Dns.Tools~~~~0.0.1.0')) {
    if ($PSCmdlet.ShouldProcess($name,'Install free RSAT capability from Windows Update')) {
        Add-WindowsCapability -Online -Name $name
    }
}
