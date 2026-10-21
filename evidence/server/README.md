# Actual DC01 evidence

Collected on 22 October 2026, Australia/Sydney, from the real Hyper-V guest running Windows Server 2022 Standard Evaluation Core. All directory accounts shown are fictional lab identities.

- `dc-live-state.json`: machine-generated domain, OU, group, policy and share inventory. Enum values are retained as returned by PowerShell JSON serialization.
- `server-acceptance.json`: **9 passed, 0 failed, 1 not run**. The explicitly excluded test requires CLIENT01 membership. These are actual guest checks, separate from mocked offline CI.
- `identity-and-recovery-transcript.txt`: actual PowerShell Direct outputs for CSV onboarding, reset with `pwdLastSet=0`, leaver disable/move/group removal, a private home ACL and object restore. The host transcript header was omitted to remove unrelated host identity; observed result lines are unchanged.
- `recycle-restore.json`: the original, deleted and restored GUID is `e65aaddb-7a18-4d45-9189-2398486f6837`; the restored account remains disabled in its original Staff OU.
- `printer-install-transcript.txt`: PnPUtil accepted the original signed Microsoft Generic/Text package; `LAB-Printer` was shared on `NUL:`. The host transcript header was omitted.
- `printer-package-validation.json`: an actual end-to-end run of the extraction script produced all 13 package files; its INF hash matches the package accepted by DC01.
- Console captures remain private pending a fresh visible guest screen. The idle blank frame was excluded from this evidence set; command outputs establish directory/service state.

The executed identity commands were `New-LabUser.ps1` with `data/onboarding.csv`, `Reset-LabUserPassword.ps1`, `Unlock-LabUser.ps1`, `Update-LabGroups.ps1` with `data/group-changes.csv`, `Export-LabStaleUsers.ps1` and `Disable-LabUser.ps1` for a separate disposable `leaver.demo`. `-WhatIf` was exercised before real operations. Passwords were passed as SecureString values and are absent from these artifacts. An unlock invocation against an unlocked account is not labelled as a completed lockout ticket.

The object-recovery commands match [the recovery runbook](../../docs/recovery.md). The restored object was disabled before deletion and remains disabled. No full System State restore is claimed.

CLIENT01 domain membership, user/computer `gpresult`, applied drive/printer preferences, RSAT GUI use, ticket screenshots, positive/negative client share access, System State backup and the demo remain pending.
