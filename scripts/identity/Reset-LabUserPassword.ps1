[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$Identity, [Parameter(Mandatory)][securestring]$NewPassword)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\..\src\Lab.Identity.psm1') -Force
Reset-LabPassword @PSBoundParameters
