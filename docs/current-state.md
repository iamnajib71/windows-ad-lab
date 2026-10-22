# Deployment state — 22 October 2026 (Australia/Sydney)

Verified on the actual lab:

- DC01 runs Windows Server 2022 Standard Evaluation Core and is the domain controller for `corp.lab` / `CORP`. The official ISOs, VM storage and temporary archive files are on H:.
- [Nine live server checks passed](../evidence/server/server-acceptance.json): directory identity, ADWS/DNS/DHCP services, protected OUs, DHCP authorisation/options, LDAP SRV resolution, password/lockout policy, Recycle Bin, AGDLP/ABE shares and expected GPO links. The CLIENT01 membership test was explicitly excluded.
- The managed Computers OU is `OU=Computers,OU=Lab,DC=corp,DC=lab`, avoiding the built-in root Computers container. Staff, Admins, Disabled and department Groups OUs are present.
- Three fictional CSV staff accounts were created, a password reset required change at next sign-in, and a separate leaver was disabled, stripped of direct groups and moved to Disabled. The private home ACL was inspected. [Actual results](../evidence/server/identity-and-recovery-transcript.txt).
- The disposable `recycle.demo` object was deleted and restored with the same GUID and original OU, remaining disabled. [Restore result](../evidence/server/recycle-restore.json).
- All eight LAB GPOs were created and linked. The shared `LAB-Printer` queue uses the signed Microsoft Generic/Text driver extracted from image 2 of the official Server evaluation ISO. PnPUtil accepted its catalog inside DC01.
- A real System State backup to the dedicated E: virtual disk completed successfully. The catalogue lists version `10/22/2026-01:43` and includes System State recovery. [Actual wbadmin output](../evidence/server/system-state-backup-transcript.txt). This does not demonstrate a System State restore.
- All three fictional staff accounts were initially checked with `pwdLastSet=0`. Alex subsequently completed the required initial password change through the native Windows API using the existing password; no password is published. [Actual change result](../evidence/server/initial-staff-password-change.json).
- A read-only observer captures lab VM consoles and memory status privately on H:. Console screenshot publication remains pending a fresh visible guest screen.

Outstanding:

- CLIENT01 has completed setup and booted Windows 11 Enterprise Evaluation build 26300. Its setup DVD drives were removed. [Actual first-boot inventory](../evidence/client/client-first-boot.json). DC01 has a CLIENT01 account in the managed Computers OU and an active `.100` DHCP lease. [Actual server observations](../evidence/server/client-account-and-lease.txt). Post-restart client verification is pending.
- VM RAM is capped at 2 GiB for DC01 and 4 GiB for CLIENT01. The 2 GiB host startup headroom check remains enabled. Domain configuration waits for installation and sufficient memory before starting both guests.
- Client domain join, DHCP lease, applied GPOs/`gpresult`, RSAT screenshots, five executed ticket evidence sets and the 30–90 second demo GIF are pending. No v1.0.0 release has been published.
- Evaluation activation/expiry and current servicing levels still require collection from each guest.

The original host-side boot-file approach was stopped and retired. The [earlier safety snapshot](../evidence/host/windows-safety-check.json) is dated 21 October and is not a fresh or binary pre/post comparison. The current workflow performs Windows setup inside lab VMs; it does not run host boot repair, mount guest VHDX files on the host or repartition host drives.

Do not rerun Prepare or replace the existing encrypted credentials. Both guests' completed setup DVD drives have been removed. Resume from verified guest state. The lab remains incomplete until the outstanding live checks and evidence are finished.
