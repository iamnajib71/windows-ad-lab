# Evidence register

Only actual machine results belong here. Every item below is **pending** unless a linked file and verification date are supplied. Mocked tests must never be labelled AD/Hyper-V integration evidence.

| Evidence | Required proof | State |
| --- | --- | --- |
| Offline validation | [Machine-generated result](local-validation.json): 27/27 current Pester tests, zero PSScriptAnalyzer findings; includes guest-setup XML and host-protection contracts | Verified 22 October 2026, Australia/Sydney |
| Host safety snapshot | [Read-only machine results](host/windows-safety-check.json): C:/H: Healthy, lab VMs off, VHDX files detached, no remaining boot-repair process | Verified 21 October 2026; no pre/post boot-store binary comparison |
| Host preparation | VM generation, Secure Boot/vTPM, switch and NAT; [actual storage migration inventory](host/storage-move-verification.json) | VMs/network created; both VM storage trees moved to E: with normal guest shutdowns on 22 October; repository/ISOs/evidence remain H: |
| Server image | [Actual guest inventory](server/dc-live-state.json) | Server Core is installed and running; the earlier host-side image approach is retired |
| Evaluation editions | [Server evaluation inventory](server/dc-live-state.json), [client evaluation inventory](client/client-first-boot.json), [server activation/expiry](server/evaluation-activation.txt) | Both evaluation editions verified; server activation succeeded until 20 April 2027; client activation check pending |
| Domain | [10 real server checks passed](server/server-with-client-acceptance.json), including DNS SRV, DHCP configuration, protected OUs and client account; [CLIENT01 membership](client/post-join-inventory.txt), [secure channel](client/secure-channel.txt) and [DHCP lease](server/dhcp-leases.json) | Verified 22 October 2026; 10 passed, 0 failed, 0 excluded |
| Onboarding/offboarding | [Actual account, reset, home ACL and leaver results](server/identity-and-recovery-transcript.txt) | Executed on DC01, 22 October 2026; console screenshots and client access tests remain pending |
| Policy | [Native GPO XML](server/server-group-policy-report.xml), [AD password policy](server/server-domain-password-policy.json), [server printer](server/printer-install-transcript.txt) and [client driver registration](client/printer-driver-registration.txt) | Eight LAB GPOs configured and recognised by Group Policy; client `gpresult`, effective registry, drives and printer connection pending |
| RSAT | ADUC, GPMC and DNS consoles running on CLIENT01 | Pending |
| Tickets 01-05 | Before/diagnose/after evidence with commands and observed outcomes | Pending |
| Recovery | [Recycle Bin restore with the same GUID](server/recycle-restore.json) and [successful System State backup/catalogue](server/system-state-backup-transcript.txt) | Verified 22 October 2026; no System State restore claimed |
| Demo | 30-90 second GIF of real onboarding and client policy application | Pending |

Store raw recordings, credentials and unreviewed transcripts in ignored `.lab` or `evidence/private`. Use only fictional lab sessions. Inspect screens for host account names, email, notifications, secrets and unrelated applications before committing. Redact private values if necessary and describe the redaction; do not alter observed outcomes. Include timestamp/timezone and SHA256 hashes for reviewed evidence. Host inventory can expose unrelated VM names: publish only this lab's selected records.

`Export-LabClientEvidence.ps1` captures actual guest command outputs. Run as the fictional domain user for user policy evidence, and separately elevated for computer policy/capabilities. A local administrator session is not proof of the fictional user's user GPO.

Demo recording plan: start with the fictional user absent; run onboarding from a prepared CSV; show the AD account/group result; switch to the domain user on CLIENT01, refresh policy or sign in, and show `gpresult` plus the department drive and desktop restriction. Record one real 30-90 second sequence. A time-compressed or edited recording must be labelled honestly. No GIF is included while deployment is pending.
