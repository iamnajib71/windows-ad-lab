# Deployment state — 22 October 2026

**Completed on 22 October 2026:** DC01 manages the domain-joined CLIENT01 through Group Policy. Real evidence covers fictional identity workflows, department permissions, client RSAT, five repaired faults, object restore and System State backup. Both VMs use the E: SSD; the repository, ISOs and evidence remain on H:. Offline mocked tests are reported separately from live guest acceptance checks.

The two-machine lab is deployed; all five support exercises are repaired. Timestamps use Australia/Sydney (UTC+11). The [learning walkthrough](learning-walkthrough.md) explains the implementation, decisions, failures and repeatable commands.

| Component | Actual result |
| --- | --- |
| DC01 | Server 2022 Standard Evaluation Core; corp.lab / CORP; AD DS, DNS, DHCP, file shares and lab printer |
| CLIENT01 | Windows 11 Enterprise Evaluation; domain joined; DHCP .100; computer in OU=Computers,OU=Lab,DC=corp,DC=lab |
| Server acceptance | [10 passed, 0 failed, 0 excluded](../evidence/server/server-with-client-acceptance.json), 19:11 |
| Standard-user acceptance | [6 passed, 0 failed, 0 excluded](../evidence/client/client-staff-acceptance.json), 19:11, actual CORP\alex.morgan session |
| Computer policy | [SMB signing required, LLMNR off, Windows Update settings](../evidence/client/client-computer-check.json); [gpresult](../evidence/client/gpresult-computer.txt) |
| User policy | [Finance/home maps, printer, restriction and access boundaries](../evidence/client/FinalChecks-state.json); [gpresult](../evidence/client/FinalChecks-gpresult.txt) |
| RSAT | [ADUC, GPMC and DNS on CLIENT01](../evidence/client/README.md#rsat); three capabilities Installed |
| Identity | [Fictional onboarding, reset/must-change and leaver execution](../evidence/server/identity-and-recovery-transcript.txt) |
| Tickets | Five deliberately reproduced and repaired faults; [runbooks](../README.md#five-support-tickets) |
| Demo | [59.62-second real capture](../evidence/client/demo.gif), new fictional account then client policy refresh |
| Recovery | [Same-GUID restore](../evidence/server/recycle-restore.json); [System State backup/catalogue](../evidence/server/system-state-backup-transcript.txt); no System State restore |
| Offline validation | [27 passed; zero analysis findings](../evidence/local-validation.json), separate from live guest checks |

VM storage is on the E: SSD under `E:\WindowsADLab`; repository, ISOs and evidence remain on H:. [Storage verification](../evidence/host/storage-move-verification.json) records the migration. Memory caps are 2/4 GiB; startup guards retain 2 GiB free host RAM.

Server evaluation expiry is 20 April 2027 at 15:13; [client activation](../evidence/client/evaluation-activation.txt) reports 20 January 2027 at 14:20:39. WMI reports client build 26300; native servicing and desktop base-build strings differ and are preserved as observed.

Limits: one DC/client, evaluation software, no production change management, no physical printer, no independent backup medium, no System State restore, no full update/restart cycle, and no Entra ID/Intune. One printer preference refresh reported 0x8007000a; subsequent refreshes and final tests show the connection. No security bypass or root-cause repair for that transient error is claimed.

The earlier host-side image approach was retired. The [21 October safety snapshot](../evidence/host/windows-safety-check.json) is historical, not a binary before/after comparison of the host boot store. Current setup occurs inside the VMs. Do not rerun Prepare or replace the existing DPAPI-protected credentials to resume this completed lab.
