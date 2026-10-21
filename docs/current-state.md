# Deployment state - 21 October 2026 (Australia/Sydney)

Verified:

- Both official evaluation ISOs downloaded onto H:; internal switch/NAT and powered-off DC01/CLIENT01 Gen 2 VMs created with VM storage on H:.
- Server evaluation image applied successfully but boot-file creation failed. The [actual transcript](../evidence/host/server-image-attempt.txt) records both results; it is not proof of a bootable guest.
- Host-side boot repair was stopped and removed from the workflow after the user requested strict protection of existing Windows. Read-only checks show the default loader points to Windows 11 on C:, C:/H: report Healthy, both VMs are off and VHDX files detached, with no boot-repair process running. This is not a pre/post binary comparison of the boot store.
- Replacement setup creates private data ISOs on H: and runs Windows Setup entirely inside each VM. Its ISO writer passed a real dummy-payload smoke test (`CD001` descriptor). Answer-file tests check guest disk 0 / partition 3 with no product keys or host paths.

Pending:

- The VM-only helper's UAC launch was cancelled; **neither guest's native setup has run**. The ignored helper is `.lab\native-setup-admin.ps1`. Old `.lab\resume-prepare-admin.ps1` is disabled and immediately throws.
- No AD forest, client domain join, live identity operations, GPO/RSAT evidence, executed tickets, recovery evidence or demo has been verified. No v1.0.0 release is published.
- Claude has now been closed. The last pre-setup reading was about 6.9 GiB free RAM. DC-only startup needs 4 GiB free; starting the client with DC running needs 6 GiB free at that point; both from stopped need 8 GiB. Safety checks remain enabled.

Do not resume host boot repair or repartition/delete host drives. New-LabSetupMedia checks each VM has only its own OS VHDX at SCSI 0:0 and no pass-through disk. The answer file replaces only that guest virtual disk. It requires live installation verification.

The prepared native-setup helper imports existing protected credentials, creates/attaches setup ISOs, opens DC01's console and starts DC-only setup/configuration. It creates no new credentials and invokes no host boot/physical-disk tools. Continue by approving that scoped elevation request or running the helper manually in elevated Windows PowerShell.
