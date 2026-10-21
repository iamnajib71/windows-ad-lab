[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$Identity)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\..\src\Lab.Identity.psm1') -Force
Unlock-LabUser @PSBoundParameters
