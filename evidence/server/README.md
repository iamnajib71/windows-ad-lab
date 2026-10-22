# Actual DC01 evidence

Collected on 22 October 2026, Australia/Sydney, from the real Hyper-V guest running Windows Server 2022 Standard Evaluation Core. All directory accounts shown are fictional lab identities.

- `dc-live-state.json`: machine-generated domain, OU, group, policy and share inventory. Enum values are retained as returned by PowerShell JSON serialization.
- `server-acceptance.json`: **9 passed, 0 failed, 1 not run**. The explicitly excluded test requires CLIENT01 membership. These are actual guest checks, separate from mocked offline CI.
- `server-with-client-acceptance.json` and its transcript: final complete run at 19:11 on 22 October: **10 passed, 0 failed, 0 not run**, including CLIENT01 in the managed Computers OU. The earlier nine-check result is retained as installation history.
- `dhcp-leases.json`: actual active CLIENT01 lease at `192.168.77.100`.
- `server-group-policy-report.xml`: unchanged native `Get-GPOReport -All -ReportType Xml` export at 15:26 on 22 October. It contains eight LAB GPOs plus the two default policies. Group Policy recognises the Drive Maps, Printers, Security and Registry extensions. This is server configuration evidence, not proof of client application. The optional HTML export failed and is not included.
- `server-domain-password-policy.json`: actual AD policy values: complexity enabled, minimum 14 characters, history 24, maximum age 90 days, minimum age one day, five-attempt lockout and 15-minute lockout/reset intervals.
- `evaluation-activation.txt`: actual activation command output: evaluation activation succeeded, with expiry reported as 20 April 2027 at 15:13. The raw `EvaluationEndDate` property returned a sentinel value; the native `/xpr` result supplies the expiry.
- `identity-and-recovery-transcript.txt`: actual PowerShell Direct outputs for CSV onboarding, reset with `pwdLastSet=0`, leaver disable/move/group removal, a private home ACL and object restore. The host transcript header was omitted to remove unrelated host identity; observed result lines are unchanged.
- `recycle-restore.json`: the original, deleted and restored GUID is `e65aaddb-7a18-4d45-9189-2398486f6837`; the restored account remains disabled in its original Staff OU.
- `printer-install-transcript.txt`: PnPUtil accepted the original signed Microsoft Generic/Text package; `LAB-Printer` was shared on `NUL:`. The host transcript header was omitted.
- `printer-package-validation.json`: an actual end-to-end run of the extraction script produced all 13 package files; its INF hash matches the package accepted by DC01.
- `ticket01-*` through `ticket05-*`: actual captured PowerShell Direct fault/repair output. Ticket 04's member-client checks are under client evidence. `demo-onboarding.txt` records the real creation of demo.onboard during the GIF. Native command output is supplied where guest transcripts omitted pipeline results.

The executed identity commands were `New-LabUser.ps1` with `data/onboarding.csv`, `Reset-LabUserPassword.ps1`, `Unlock-LabUser.ps1`, `Update-LabGroups.ps1` with `data/group-changes.csv`, `Export-LabStaleUsers.ps1` and `Disable-LabUser.ps1` for a separate disposable `leaver.demo`. `-WhatIf` was exercised before real operations. Passwords were passed as SecureString values and are absent from these artifacts. An unlock invocation against an unlocked account is not labelled as a completed lockout ticket.

The object-recovery commands match [the recovery runbook](../../docs/recovery.md). The restored object was disabled before deletion and remains disabled. No full System State restore is claimed.

- `dc-final-check.json`: actual staff must-change flags (`pwdLastSet=0`), disabled leaver state, shared printer and dedicated backup volume inventory collected before backup.
- `system-state-backup.json`: guest completion timestamp and target.
- `system-state-backup-transcript.txt`: unchanged native `wbadmin` output from the host PowerShell Direct transcript, excluding the unrelated host header and startup connection retry. It includes successful completion and catalogue version `10/22/2026-01:43`, with System State among the recoverable items. Native command output was not captured in the guest transcript, so the host-captured output is supplied here. Times are retained exactly as each command reported them.

CLIENT01 user/computer policy, RSAT, positive/negative access, five tickets and the demo are now verified: see the [client evidence](../client/README.md) and [register](../README.md). No blank idle frame is presented as console evidence.

`sha256.csv` hashes the published Git blob bytes of the machine-generated JSON and transcript files. Git may convert line endings in a Windows checkout; use the raw published files or `git show` bytes when verifying these hashes. This explanatory README is excluded from the manifest.
