#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param([ValidatePattern('^[D-Z]:$')][string]$BackupTarget='E:')
$ErrorActionPreference='Stop'
if ($env:COMPUTERNAME -ne 'DC01') { throw 'Run inside DC01 only.' }
if (-not (Test-Path -LiteralPath "$BackupTarget\")) { throw 'Attach and initialise a dedicated backup VHDX first. Do not use the OS volume.' }
if ($PSCmdlet.ShouldProcess($BackupTarget,'Create DC01 System State backup')) {
    $null=Install-WindowsFeature Windows-Server-Backup
    & wbadmin.exe start systemstatebackup "-backupTarget:$BackupTarget" -quiet
    if ($LASTEXITCODE -ne 0) { throw "System State backup failed: $LASTEXITCODE" }
    & wbadmin.exe get versions "-backupTarget:$BackupTarget"
    if ($LASTEXITCODE -ne 0) { throw 'Backup catalogue verification failed.' }
}
