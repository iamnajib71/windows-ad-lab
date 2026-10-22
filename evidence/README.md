# Evidence register

Actual machine outputs, reviewed guest screenshots and a real guest recording. Verification date: 22 October 2026, Australia/Sydney. Offline tests mock AD and are separate from live checks.

| Evidence | Observed result |
| --- | --- |
| [Offline validation](local-validation.json) | 27 tests passed; zero PSScriptAnalyzer findings |
| [Server acceptance](server/server-with-client-acceptance.json) | 10 passed, 0 failed, 0 excluded, including CLIENT01 account |
| [Client acceptance](client/client-staff-acceptance.json) | 6 passed, 0 failed, 0 excluded as standard user Alex |
| [Computer policy](client/client-computer-check.json) | Domain join, healthy channel, SMB signing, LLMNR and update values |
| [User policy and permissions](client/FinalChecks-state.json) | Finance/own home allowed; HR/other home denied; maps, restriction, printer |
| [User gpresult](client/FinalChecks-gpresult.txt) / [computer gpresult](client/gpresult-computer.txt) | Actual applied policies from DC01 |
| [Identity execution](server/identity-and-recovery-transcript.txt) | Fictional onboarding, reset, home ACL and leaver |
| [Native GPO export](server/server-group-policy-report.xml) | Eight LAB GPOs; client processing verified separately |
| [RSAT](client/README.md#rsat) | ADUC, GPMC and DNS consoles on CLIENT01 |
| [Five tickets](../README.md#five-support-tickets) | Deliberately reproduced and repaired, with commands and evidence |
| [Object restore](server/recycle-restore.json) | Same GUID and original OU, remaining disabled |
| [System State backup](server/system-state-backup-transcript.txt) | Completed and catalogued; no System State restore claimed |
| [Server activation](server/evaluation-activation.txt) / [client activation](client/evaluation-activation.txt) | Evaluation editions and expiry |
| [Demo and provenance](client/README.md#demo) | 59.62 seconds: onboarding and client policy refresh |
| [Storage migration](host/storage-move-verification.json) | Guest storage E: SSD; repo/media/evidence H: |
| [Historical safety snapshot](host/windows-safety-check.json) | Dated 21 October; no host boot-store binary comparison |

Ticket 02/03 screenshots and the share repair were captured during the exercises. Ticket 01/04 and the readable ticket-05 summary are explicitly labelled **recorded-result reviews** on CLIENT01, backed by original before/after files. They are not live sign-in error screenshots. No image simulates the lab.

The demo manifest retains frame times/hashes; source frames and protected setup media remain private. Only fictional guest identities are published. No passwords, credential objects, ISOs, VHDX files or unrelated host data are included.

Server/client/host sha256.csv manifests hash committed bytes, accounting for Git text normalisation. UTF-16 text was transcoded to UTF-8 for browser readability. Three client transcripts replace only their Host Application transport-metadata header with an explicit redaction; observed result text is unchanged. Old setup evidence remains historical. The client WMI build is 26300; differing native servicing/base strings are preserved. A historical printer preference error is documented rather than erased.

Use the [learning walkthrough](../docs/learning-walkthrough.md) to repeat the checks and understand the limits.
