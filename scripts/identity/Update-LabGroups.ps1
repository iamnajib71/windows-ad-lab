[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$CsvPath)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\..\src\Lab.Identity.psm1') -Force
Update-LabGroupMembership @PSBoundParameters
