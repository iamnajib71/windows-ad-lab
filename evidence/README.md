# Evidence register

Only actual machine results belong here. Every item below is **pending** unless a linked file and verification date are supplied. Mocked tests must never be labelled AD/Hyper-V integration evidence.

| Evidence | Required proof | State |
| --- | --- | --- |
| Offline validation | [Machine-generated result](local-validation.json): 27/27 Pester tests, zero PSScriptAnalyzer findings; acceptance files parse only | Verified 21 October 2026, Australia/Sydney |
| Host preparation | VM generation, Secure Boot/vTPM, paths on H:, switch and NAT | VMs/network created; final inventory pending |
| Server image | [Actual DISM/BCDBoot transcript excerpt](host/server-image-attempt.txt) | Image applied successfully; boot-file setup failed; repair unverified |
| Evaluation editions | `Get-ComputerInfo` / `DISM /Online /Get-CurrentEdition`, licence expiry from each guest | Pending |
| Domain | `Get-ADDomain`; CLIENT01 `PartOfDomain=True`; DNS SRV and DHCP lease | Pending |
| Onboarding/offboarding | Actual account, home ACL, group and leaver OU results | Pending |
| Policy | User and computer `gpresult`, refresh, effective registry, drives, virtual printer | Pending |
| RSAT | ADUC, GPMC and DNS consoles running on CLIENT01 | Pending |
| Tickets 01-05 | Before/diagnose/after evidence with commands and observed outcomes | Pending |
| Recovery | Recycle Bin restore with same GUID and successful System State catalogue | Pending |
| Demo | 30-90 second GIF of real onboarding and client policy application | Pending |

Store raw recordings, credentials and unreviewed transcripts in ignored `.lab` or `evidence/private`. Use only fictional lab sessions. Inspect screens for host account names, email, notifications, secrets and unrelated applications before committing. Redact private values if necessary and describe the redaction; do not alter observed outcomes. Include timestamp/timezone and SHA256 hashes for reviewed evidence. Host inventory can expose unrelated VM names: publish only this lab's selected records.

`Export-LabClientEvidence.ps1` captures actual guest command outputs. Run as the fictional domain user for user policy evidence, and separately elevated for computer policy/capabilities. A local administrator session is not proof of the fictional user's user GPO.

Demo recording plan: start with the fictional user absent; run onboarding from a prepared CSV; show the AD account/group result; switch to the domain user on CLIENT01, refresh policy or sign in, and show `gpresult` plus the department drive and desktop restriction. Record one real 30-90 second sequence. A time-compressed or edited recording must be labelled honestly. No GIF is included while deployment is pending.
