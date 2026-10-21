# Ticket 02 - Wrong department drive mapping

Status: **pending live execution**. This runbook does not claim a resolved incident.

Scenario: Alex's F: drive points at HR instead of Finance. Prerequisites: onboarding complete, Alex in GG_Finance, known-good drive application captured.

## Reproduce

In CLIENT01 GPMC using a lab admin identity, edit **LAB-Drive-Finance -> User Configuration -> Preferences -> Windows Settings -> Drive Maps**. Change only the F: item's path from `\\DC01\Finance` to `\\DC01\HR`. Preserve GG_Finance item-level targeting. Refresh policy in Alex's session. The incorrect target should be denied by HR permissions, rather than exposing HR data. Record what actually happens: a failed mapping may leave no F: mapping or retain an older one.

## Diagnose

In Alex's CLIENT01 session:

```powershell
whoami /groups
Get-SmbMapping
gpresult /r
gpresult /h C:\LabEvidence\ticket02-before.html /f
Test-Path \\DC01\Finance
Test-Path \\DC01\HR
```

In the lab admin session:

```powershell
Get-ADPrincipalGroupMembership alex.morgan | Select-Object Name
Get-GPOReport -Name LAB-Drive-Finance -ReportType Xml -Path C:\LabEvidence\ticket02-policy.xml
Get-WinEvent -LogName 'Microsoft-Windows-GroupPolicy/Operational' -MaxEvents 30 |
    Select-Object TimeCreated,Id,Message
```

Compare the intended UNC, actual preference, drive letter, user token, targeting group and file-service access. The AD group listing and the existing sign-in token can differ after membership changes. A successful `gpupdate` does not prove a successful drive preference.

## Fix and verify

Correct the item back to `\\DC01\Finance` in GPMC, or run the declarative `Set-LabGroupPolicy.ps1` on DC01 after reviewing that it reapplies all LAB policy settings. Use `gpupdate /target:user /force`, then sign out/in if token or persistence state requires it. Confirm F: targets Finance and Alex can create/read a fictional test file; HR stays inaccessible. Save `Get-SmbMapping` and a new `gpresult` report.

## Prevent

Use one declared UNC per department, distinct F:/R:/I: letters, group targeting and a test user for each department. Review changes against the policy source and verify positive and negative access before calling the ticket resolved.

## Evidence / observed result

- Before: failed/wrong F: mapping in Alex's session - pending.
- Diagnosis: GPMC incorrect path, targeting and user token - pending.
- After: correct F: and successful Finance-only file access - pending.
- Root cause, actual commands, event IDs and timestamps - pending.
