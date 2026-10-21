[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$CsvPath, [Parameter(Mandatory)][securestring]$InitialPassword, [string]$HomeRoot='C:\LabData\Homes')
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\..\src\Lab.Identity.psm1') -Force
Invoke-LabOnboarding @PSBoundParameters
