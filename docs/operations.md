# Identity and RSAT operations

The entry scripts import `ActiveDirectory` and the shared module. Run from `C:\LabRepo` on DC01. Use a lab administrative session for setup, and ordinary fictional users for access/policy verification. Standard staff accounts must never be placed in Domain Admins.

| Script | Purpose | Inputs / boundary |
| --- | --- | --- |
| `New-LabUser.ps1` | Onboard, home H:, department group, mail-style core AD attributes | Validated CSV, supplied SecureString password; only `corp.lab` |
| `Reset-LabUserPassword.ps1` | Reset plus must-change | Staff/Disabled OU identity and SecureString |
| `Unlock-LabUser.ps1` | Unlock | Staff/Disabled OU identity |
| `Disable-LabUser.ps1` | Disable, remove all direct MemberOf groups, move to Disabled | Staff/Disabled OU only; high impact confirmation |
| `Update-LabGroups.ps1` | CSV bulk Add/Remove | Only `GG_Finance`, `GG_HR`, `GG_IT`; whole-file dependency validation |
| `Export-LabStaleUsers.ps1` | Approximate inactivity report | Default 90 days, optional output CSV; never-used accounts must also be old |

Every entry point supports `-WhatIf`. It can still read AD and validate dependencies; it does not create users, directories, files or modify memberships. An existing username/home folder aborts onboarding; rerunning onboarding is intentionally not an update operation. Use `Get-LabOnboardingPlan` without AD to review the CSV locally.

```powershell
Import-Module .\src\Lab.Identity.psm1
Get-LabOnboardingPlan .\data\onboarding.csv | Format-Table

# Real verification after onboarding, not sample output:
Get-ADUser alex.morgan -Properties Department,Title,mail,HomeDirectory,HomeDrive,pwdLastSet,Enabled |
    Select-Object SamAccountName,Enabled,Department,Title,mail,HomeDirectory,HomeDrive,pwdLastSet
Get-ADPrincipalGroupMembership alex.morgan | Select-Object Name
Get-Acl C:\LabData\Homes\alex.morgan | Format-List
```

`pwdLastSet=0` means the next interactive sign-in must change the temporary password. Complete that change as the fictional user before collecting normal user-session evidence. Read passwords using secure prompts; do not type them as command-line literals. For this small exercise the CSV batch uses one supplied temporary password; a production process would issue unique credentials through an approved secure channel.

The leaver script does not revoke existing Kerberos tickets, log off sessions, close SMB handles, delete homes or handle Microsoft 365. Check existing sessions separately. It retains the primary Domain Users group. Review leavers and membership logs as normal support practice; no automatic deletion occurs.

RSAT from CLIENT01:

1. Run `Install-LabRSAT.ps1` as the guest local/domain admin. Confirm the three capability states are Installed.
2. Sign in with an appropriate lab admin identity for console administration. Open `dsa.msc`, connect to `corp.lab`, and show the OU tree and fictional users.
3. Open `gpmc.msc`, show domain/OU links and one policy's Settings tab.
4. Open `dnsmgmt.msc`, connect to DC01 and inspect `corp.lab` plus `_msdcs` SRV records. The DNS console may initially show the local computer; explicitly connect to the server.
5. Save one screenshot per console from CLIENT01. ADUC running on DC01 is not proof of client RSAT.

Use guest `Start-Transcript` only after credentials have been entered and before nonsecret diagnostic commands. Stop it before any password changes. Review transcripts before copying into the evidence folder.

For repeatable staff-session evidence, run `scripts/client/Invoke-LabStaffEvidence.ps1 -Step Baseline` from the actual `CORP\alex.morgan` session on CLIENT01. It records user `gpupdate`/`gpresult`, mappings, printers, desktop policy and permitted/denied share access under that fictional profile's Documents directory. `-Step FinalChecks` also runs the real client acceptance tests. Ticket-specific steps capture the observed fault or repair; they do not inject server faults or replace actual troubleshooting.
