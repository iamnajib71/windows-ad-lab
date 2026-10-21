[CmdletBinding(SupportsShouldProcess)]
param([ValidateRange(1,3650)][int]$InactiveDays=90, [string]$OutputPath)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\..\src\Lab.Identity.psm1') -Force
Get-LabStaleAccount @PSBoundParameters
