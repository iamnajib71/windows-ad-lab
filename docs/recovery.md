# Backup and recovery runbook

Status: a real Recycle Bin restore was verified on 22 October 2026, retaining the same object GUID before deletion and after restore. See [the machine-generated result](../evidence/server/recycle-restore.json) and [actual transcript excerpt](../evidence/server/identity-and-recovery-transcript.txt). System State backup remains pending until a successful catalogue is recorded.

`Initialize-LabDomain.ps1` enables AD Recycle Bin after forest creation. It is a forest-wide, irreversible feature enablement, suitable here because this is a new isolated evaluation forest. It does not restore objects deleted before enablement.

Use a **dedicated temporary fictional account** for the restore exercise rather than a ticket/onboarding account:

```powershell
# DC01 lab admin; use only this exact disposable identity.
New-ADUser -Name 'Recycle Demo' -SamAccountName recycle.demo -Path 'OU=IT,OU=Staff,DC=corp,DC=lab' -Enabled $false
$object = Get-ADUser recycle.demo
$restoreGuid = $object.ObjectGUID
$object | Select-Object SamAccountName,ObjectGUID,DistinguishedName
Remove-ADUser -Identity $restoreGuid -Confirm
Get-ADObject -Identity $restoreGuid -IncludeDeletedObjects -Properties isDeleted,lastKnownParent |
    Select-Object ObjectGUID,isDeleted,lastKnownParent
.\scripts\server\Restore-LabObject.ps1 -ObjectGuid $restoreGuid -WhatIf
.\scripts\server\Restore-LabObject.ps1 -ObjectGuid $restoreGuid
Get-ADUser -Identity $restoreGuid | Select-Object SamAccountName,ObjectGUID,DistinguishedName,Enabled
```

Capture the same GUID before deletion, while deleted, and after restore. Compare the original OU and enabled state. The restore helper accepts only a deleted object whose parent is under Staff. A restore proves object recovery only; it is not a full AD disaster-recovery exercise. Keep this test account disabled afterwards.

System State backup:

1. `Add-LabBackupDisk.ps1` attaches a new dynamic 40 GiB VHDX on host H:.
2. Inside DC01, inspect `Get-Disk`. `Initialize-LabBackupDisk.ps1` only formats exactly one RAW, non-system, non-boot 40 GiB disk, and stops if the selected drive letter is already used. Never initialise an existing/data/host disk. Default is E:.
3. Start the real backup and preserve the success/failure result and catalogue:

```powershell
.\scripts\server\Initialize-LabBackupDisk.ps1 -WhatIf
# Configure normally already initialises the disk; do not run twice.
.\scripts\server\Backup-LabSystemState.ps1 -BackupTarget E: -WhatIf
.\scripts\server\Backup-LabSystemState.ps1 -BackupTarget E:
wbadmin get versions -backupTarget:E:
Get-WinEvent -LogName 'Microsoft-Windows-Backup' -MaxEvents 10 |
    Select-Object TimeCreated,Id,LevelDisplayName,Message
```

Windows Server Backup is installed by the forest setup and checked by the backup script. The script rejects C:, checks the target exists, checks `wbadmin` exit codes and lists the backup catalogue. A directory called WindowsImageBackup alone is not success evidence. Allow sufficient free H: and guest backup space before running.

The `wbadmin start systemstatebackup` command follows [Microsoft's reference](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/wbadmin-start-systemstatebackup). A real System State restore would require a separate recovery test, DSRM credentials, a documented authoritative/non-authoritative decision and verification. This project does not automate or claim that destructive recovery. Hyper-V checkpoints are not a replacement for backup, and this same-physical-disk backup cannot survive H: failure.
