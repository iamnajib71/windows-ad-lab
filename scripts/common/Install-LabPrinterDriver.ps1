#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param([string]$DriverPackagePath='C:\LabDrivers\GenericTextOnly')
$ErrorActionPreference='Stop'
if ($env:COMPUTERNAME -notin @('DC01','CLIENT01')) { throw 'Run only inside a named lab guest.' }
Import-Module PrintManagement
$name='Generic / Text Only'
if (Get-PrinterDriver -Name $name -ErrorAction SilentlyContinue) { return }
# Register the Microsoft-signed package extracted from the evaluation ISO.
# PnPUtil verifies it when staging; no unsigned-driver override is used.
if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME,"Stage and register signed $name printer driver")) { return }
$store=Join-Path $env:SystemRoot 'System32\DriverStore\FileRepository'
$packages=@(Get-ChildItem -LiteralPath $store -Directory | Where-Object Name -Match '^prnge001\.inf_amd64_')
if (-not $packages.Count) {
    $packageInf=Join-Path $DriverPackagePath 'prnge001.inf'
    if (-not (Test-Path -LiteralPath $packageInf)) { throw 'Copy the original GenericTextOnly package from the evaluation ISO into the guest first.' }
    & pnputil.exe /add-driver $packageInf
    if ($LASTEXITCODE -ne 0) { throw "Signed printer package staging failed: $LASTEXITCODE" }
    $packages=@(Get-ChildItem -LiteralPath $store -Directory | Where-Object Name -Match '^prnge001\.inf_amd64_')
}
$inf=@($packages | Get-ChildItem -Filter *.inf -File | Where-Object {
    Select-String -LiteralPath $_.FullName -Pattern $name -SimpleMatch -Quiet
} | Sort-Object FullName)
if (-not $inf.Count) { throw 'The signed Generic / Text Only package was not found after staging.' }
Add-PrinterDriver -Name $name -InfPath $inf[0].FullName
