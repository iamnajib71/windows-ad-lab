#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference='Stop'
if ($env:COMPUTERNAME -ne 'DC01') { throw 'Run inside DC01 only.' }
if ($PSCmdlet.ShouldProcess('DC01 / LAB-Printer','Install a lab-only print service and virtual discard queue')) {
    $null=Install-WindowsFeature Print-Server -IncludeManagementTools
    Import-Module PrintManagement
    if (-not (Get-PrinterDriver -Name 'Generic / Text Only' -ErrorAction SilentlyContinue)) {
        & "$PSScriptRoot\..\common\Install-LabPrinterDriver.ps1"
    }
    if (-not (Get-PrinterPort -Name 'NUL:' -ErrorAction SilentlyContinue)) { Add-PrinterPort -Name 'NUL:' }
    if (-not (Get-Printer -Name LAB-Printer -ErrorAction SilentlyContinue)) {
        Add-Printer -Name LAB-Printer -DriverName 'Generic / Text Only' -PortName 'NUL:' -Shared -ShareName LAB-Printer -Published
    }
    Get-Printer -Name LAB-Printer | Select-Object Name,DriverName,PortName,Shared,ShareName
}
