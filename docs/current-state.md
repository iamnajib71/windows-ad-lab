# Deployment state — 22 October 2026 (Australia/Sydney)

Verified on the actual lab:

- DC01 runs Windows Server 2022 Standard Evaluation Core and is the domain controller for `corp.lab` / `CORP`. The official ISOs, VM storage and temporary archive files are on H:.
- [Nine live server checks passed](../evidence/server/server-acceptance.json): directory identity, ADWS/DNS/DHCP services, protected OUs, DHCP authorisation/options, LDAP SRV resolution, password/lockout policy, Recycle Bin, AGDLP/ABE shares and expected GPO links. The CLIENT01 membership test was explicitly excluded.
- The managed Computers OU is `OU=Computers,OU=Lab,DC=corp,DC=lab`, avoiding the built-in root Computers container. Staff, Admins, Disabled and department Groups OUs are present.
- Three fictional CSV staff accounts were created, a password reset required change at next sign-in, and a separate leaver was disabled, stripped of direct groups and moved to Disabled. The private home ACL was inspected. [Actual results](../evidence/server/identity-and-recovery-transcript.txt).
- The disposable `recycle.demo` object was deleted and restored with the same GUID and original OU, remaining disabled. [Restore result](../evidence/server/recycle-restore.json).
- All eight LAB GPOs were created and linked. The shared `LAB-Printer` queue uses the signed Microsoft Generic/Text driver extracted from image 2 of the official Server evaluation ISO. PnPUtil accepted its catalog inside DC01.
- The dedicated 40 GiB dynamic backup VHDX was initialised inside DC01 as E:, labelled `LAB-Backup`. This is preparation, not proof of a successful backup.
- A read-only observer captures lab VM consoles and memory status privately on H:. Console screenshot publication remains pending a fresh visible guest screen.

Outstanding:

- CLIENT01 remains off and uninstalled. The latest readings were around 4.2 GiB free RAM; safe startup requires 6 GiB free while DC01 is running. The 2 GiB host headroom check remains enabled.
- The System State backup helper has been prepared/requested. A successful `wbadmin` catalogue must be recorded before it is marked complete.
- Client domain join, DHCP lease, applied GPOs/`gpresult`, RSAT screenshots, five executed ticket evidence sets and the 30–90 second demo GIF are pending. No v1.0.0 release has been published.
- Evaluation activation/expiry and current servicing levels still require collection from each guest.

The original host-side boot-file approach was stopped and retired. The [earlier safety snapshot](../evidence/host/windows-safety-check.json) is dated 21 October and is not a fresh or binary pre/post comparison. The current workflow performs Windows setup inside lab VMs; it does not run host boot repair, mount guest VHDX files on the host or repartition host drives.

Do not rerun Prepare or replace the existing encrypted credentials. DC01's completed setup DVD drives have been removed. Resume from verified guest state; CLIENT01 still needs its attached setup media. The lab remains incomplete until the outstanding live checks and evidence are finished.
