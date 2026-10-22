# Build, understand and revisit the lab

This is the learning record for the actual build completed on 22 October 2026. Start with the [59.6-second demo](../evidence/client/demo.gif), then work through one section at a time. Commands below are instructions to run in the named machine; linked evidence contains the observed results. Passwords and unattended setup files remain private.

## 1. Understand what each machine does

DC01 is Windows Server 2022 Standard Evaluation **Server Core**. It provides the `corp.lab` directory, DNS, DHCP, file shares and a lab printer. Server Core has a text sign-in and administrative interface; it does not have the full Windows desktop. CLIENT01 is Windows 11 Enterprise Evaluation, joined to the domain and managed by policy.

The internal Hyper-V switch uses `192.168.77.0/24`. The host's lab gateway is `.1`, DC01 is `.10`, and CLIENT01 received `.100` from DC01's DHCP scope. An internal switch plus NAT gives outbound access without exposing the lab DHCP server to the home network. The client uses DC01 for DNS so it can find AD's LDAP and Kerberos service records.

The repository, evaluation ISOs, scratch files and evidence are on H:. VM configuration and virtual disks are under `E:\WindowsADLab\DC01` and `E:\WindowsADLab\CLIENT01`. Paths such as guest `C:\LabRepo` and `C:\LabData` are **inside the VMs' virtual disks**, not directories on the host C: drive. Normal host Windows files, logs and paging still use C:.

Read [architecture and skills](../README.md#architecture), [build guide](build-guide.md), and [actual storage verification](../evidence/host/storage-move-verification.json).

## 2. Build order and why it matters

| Order | Work performed | Reason and verification |
| --- | --- | --- |
| 1 | Download official Server 2022 and Windows 11 Enterprise evaluation ISOs; inspect media | Establish the actual editions rather than trusting a filename. No product keys were supplied. |
| 2 | Create internal switch/NAT, Generation 2 VMs, Secure Boot, vTPM and private setup media | Keep DHCP isolated; satisfy Windows 11 requirements; install into guest disks. |
| 3 | Install Windows using setup media inside each VM | Avoid host disk mounting, physical disk partitioning or boot repair. |
| 4 | Give DC01 its static address; install AD DS/DNS and create `corp.lab` | The directory and its DNS must exist before a client can join. |
| 5 | Create OUs, groups, DHCP, shares and GPOs | Establish destinations and permissions before onboarding users. |
| 6 | Onboard fictional staff, join CLIENT01 and place it in the managed Computers OU | Domain membership alone does not put a computer under the intended OU-linked policies. |
| 7 | Install RSAT and the signed lab printer driver inside CLIENT01 | Tools and driver availability must be verified on the client itself. |
| 8 | Verify policy and access as standard user Alex | An administrator's access does not prove ordinary staff permissions. |
| 9 | Reproduce and repair five isolated support faults | Verify the diagnosis with actual before/after results. |
| 10 | Test recovery, run acceptance tests, record the demo and publish reviewed evidence | Separate real integration checks from mocked offline tests. |

The entry point is `scripts/host/Invoke-LabBuild.ps1`. `-Stage Prepare -WhatIf` previews preparation; Configure uses PowerShell Direct to work inside the guests. **Do not rerun Prepare against this completed lab or replace its protected credential files.** Use the existing machines for practice. All identity changes support `-WhatIf`.

The build required administrative Windows approval for Hyper-V operations. Background helpers were scoped to DC01/CLIENT01. Windows UAC cancellation means a helper did not start; waiting longer does not grant approval. The current repository does not run host boot repair. An earlier host-side image approach was stopped and retired before adopting VM-only Windows Setup; [the dated safety snapshot](../evidence/host/windows-safety-check.json) is not a binary before/after proof of the host boot store.

## 3. Start and stop the existing lab

On the **host**, open elevated Windows PowerShell. Start DC01 first, allow AD/DNS to become available, then start CLIENT01. The guarded start script checks memory headroom; the two guests are capped at 2 GiB and 4 GiB.

```powershell
Set-Location 'H:\My Projects - IT\windows-ad-lab'
.\scripts\host\Start-Lab.ps1 -VMName DC01 -WhatIf
.\scripts\host\Start-Lab.ps1 -VMName DC01
# Wait for DC01's AD/DNS services, then:
.\scripts\host\Start-Lab.ps1 -VMName CLIENT01
Get-VM DC01,CLIENT01 | Select-Object Name,State,MemoryAssigned,Status
vmconnect.exe localhost CLIENT01
```

In Virtual Machine Connection use **Action → Ctrl+Alt+Delete** to send the secure attention sequence to the guest. Pressing Ctrl+Alt+Delete on the physical keyboard opens the host's security screen. A connection/session dialog or Esc press does not itself establish damage.

Use the private lab credentials; never paste them into README files, commands, screenshots or chat. DC01's domain administrator is `CORP\Administrator`; CLIENT01 also retains `CLIENT01\LabAdmin` for local recovery. Ordinary access checks use `CORP\alex.morgan`. A newly onboarded account must change its temporary password before normal use.

Shut down the **guests** normally before turning off the host. From elevated host PowerShell:

```powershell
Stop-VM -Name CLIENT01
Stop-VM -Name DC01
Get-VM DC01,CLIENT01 | Select-Object Name,State
```

Do not use `-TurnOff` for routine shutdown. Leave existing VMs and their DPAPI-protected credentials intact. Evaluation licences expire; keep the evidence and plan a fresh evaluation rebuild when needed rather than using activation bypasses.

## 4. Read the directory design

Staff, Admins, Disabled and Groups are OUs below `DC=corp,DC=lab`, with department OUs below Staff and Groups. The managed Computers OU is `OU=Computers,OU=Lab,DC=corp,DC=lab`, distinct from AD's built-in `CN=Computers` container.

On **DC01**:

```powershell
Import-Module ActiveDirectory
Get-ADDomain | Select-Object DNSRoot,NetBIOSName,DomainMode
Get-ADOrganizationalUnit -Filter * -SearchBase 'DC=corp,DC=lab' |
    Select-Object Name,DistinguishedName
Get-ADComputer CLIENT01 | Select-Object Name,DistinguishedName
```

AGDLP means **Accounts → Global group → Domain Local group → Permission**. Alex belongs to `GG_Finance`; that is nested in `DL_Finance_Modify`; the latter has the Finance permissions. This lets you change staff membership without editing every folder ACL. Staff accounts are not Domain Admins.

## 5. Practise onboarding and offboarding

On **DC01**, from `C:\LabRepo`, inspect `data/onboarding.csv` and `src/Lab.Identity.psm1`. Plan before writing:

```powershell
Import-Module .\src\Lab.Identity.psm1
Get-LabOnboardingPlan .\data\onboarding.csv | Format-Table
$temporary = Read-Host 'Temporary fictional-user password' -AsSecureString
.\scripts\identity\New-LabUser.ps1 -CsvPath .\data\onboarding.csv -InitialPassword $temporary -WhatIf
```

The sample accounts already exist, so real onboarding will reject duplicates. For your own practice, copy the CSV and use a new fictional username in a supported department. Review `-WhatIf`, then run without it. The script validates the batch, creates each account disabled, assigns its private home and department group, and enables it only after those steps succeed. A failure is not a transaction: completed earlier accounts remain; an incomplete account stays disabled.

Verify the actual result:

```powershell
Get-ADUser demo.onboard -Properties Department,mail,HomeDirectory,pwdLastSet |
    Select-Object SamAccountName,Enabled,Department,mail,HomeDirectory,pwdLastSet
Get-ADPrincipalGroupMembership demo.onboard | Select-Object Name
```

`pwdLastSet=0` means change password at next sign-in. `mail` is an AD attribute using `.invalid`; it does not create an Exchange mailbox. The demo created Robin Ellis / `demo.onboard` on DC01 while CLIENT01 watched the directory; the policy refresh then ran as the existing standard user Alex. Those are separate identities, clearly identified in the recording.

Review the reset, unlock, group-change and stale-report examples in [operations](operations.md). For a disposable leaver, preview `Disable-LabUser.ps1`; it disables the account, removes direct memberships and moves it to Disabled. It retains the home for review and does not revoke existing sessions or cloud access. Do not offboard Alex while you still need the standard-user demonstrations.

## 6. Verify DNS, DHCP and trust

On **CLIENT01**:

```powershell
ipconfig /all
Resolve-DnsName _ldap._tcp.dc._msdcs.corp.lab -Type SRV -Server 192.168.77.10
Test-ComputerSecureChannel -Verbose # elevated guest session
```

On **DC01**:

```powershell
Get-DhcpServerv4Lease -ScopeId 192.168.77.0
Get-DhcpServerv4OptionValue -ScopeId 192.168.77.0
```

A working ping is insufficient. DNS locates the DC; DHCP supplies client configuration; the secure-channel check verifies the machine's trust. [Ticket 04](tickets/04-computer-trust.md) shows an actual false result after a directory-side machine-password reset and a true result after scoped repair. A client rejoin or DC rollback was unnecessary.

## 7. Learn policy processing from both sides

On **CLIENT01 as Alex**:

```powershell
whoami
whoami /groups
gpupdate /target:user /force
gpresult /scope user /r
gpresult /scope user /h "$HOME\Documents\user-policy.html" /f
Get-SmbMapping
Get-Printer
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name NoControlPanel
```

Computer policy requires a separate elevated guest session: `gpupdate /target:computer /force` and `gpresult /scope computer /r`. The verified settings include SMB signing required, LLMNR disabled, and Windows Update registry configuration. Configured update settings do not prove a full patch installation or restart cycle.

Scope, link state, group filtering and client refresh are separate questions. [Ticket 03](tickets/03-gpo-not-applying.md) disabled the Staff OU's desktop GPO link: `NoControlPanel` disappeared and Control Panel opened. Re-enabling the link and refreshing restored the restriction. [Ticket 02](tickets/02-wrong-drive-mapping.md) changed a drive's target; granting more access would have hidden that configuration error.

Open `dsa.msc`, `gpmc.msc` and `dnsmgmt.msc` on CLIENT01 with an appropriate lab administrative identity. Connect the DNS console explicitly to DC01. [RSAT screenshots](../evidence/client/README.md) show the actual consoles. Standard staff can read much of AD but cannot administer it.

## 8. Test permissions by doing the operation

On **CLIENT01 as Alex**, list Finance and the own home; try listing HR and another user's home. A denied or hidden path is the expected negative result. Access-based enumeration hides inaccessible entries; it does not grant permission. Share and NTFS permissions both apply; the effective intersection wins.

```powershell
Get-ChildItem \\DC01\Finance -ErrorAction Stop
Get-ChildItem \\DC01\Homes\alex.morgan -ErrorAction Stop
Get-ChildItem \\DC01\HR -ErrorAction Stop
Get-ChildItem \\DC01\Homes\jamie.chen -ErrorAction Stop
```

An existence probe such as `Test-Path` can observe cached metadata. We changed the acceptance check to attempt directory enumeration with `-ErrorAction Stop`, which tests the requested access more directly. The actual acceptance test proves Alex's positive and negative access boundaries. [Ticket 05](tickets/05-share-access.md) removed the Finance share grant while leaving NTFS and group membership intact; restoring only that grant fixed access.

## 9. Revisit the five tickets

Follow [01 lockout](tickets/01-locked-out-user.md), [02 mapping](tickets/02-wrong-drive-mapping.md), [03 GPO](tickets/03-gpo-not-applying.md), [04 trust](tickets/04-computer-trust.md), and [05 share](tickets/05-share-access.md). Each records reproduce → diagnose → fix → prevent, commands and the actual outcome. Introduce one fault at a time in this disposable lab and restore it before moving on.

Screenshots for tickets 02/03 and the share repair show the guest during the exercise. Tickets 01/04 and the readable ticket-05 summary show **explicitly labelled recorded-result reviews** on CLIENT01. Their source files contain actual captured before/after outputs; these images are not live sign-in-failure screenshots. This distinction is part of keeping evidence accurate.

For every exercise, write your own explanation: what failed, what evidence narrowed the cause, why the chosen change was sufficient, and what result proves recovery. Avoid learning only the repair command.

## 10. Understand the recovery demonstration

AD Recycle Bin was enabled. A disposable object was deleted and restored with the same GUID and original OU. A real System State backup completed using Windows Server Backup, and its catalogue lists System State recovery. See [recovery commands and evidence](recovery.md).

Object restore and System State backup solve different problems. This lab **does not demonstrate a System State restore**. The virtual backup disk shares the guests' physical SSD, so it does not protect against physical disk/host loss. A checkpoint is not a substitute for an AD backup.

## 11. Lessons from the build's delays

| Observation | Action and lesson |
| --- | --- |
| Insufficient free RAM while both guests and other applications were running | Start checks retained 2 GiB host headroom; applications were left for the user to close. Allocate resources before installation. |
| H: mechanical disk had long I/O delays | Moved only the lab's VM storage to E: SSD using Hyper-V storage relocation after guest shutdown. Kept repository/ISOs/evidence on H:. |
| RSAT servicing was slow; a PowerShell DISM capability call failed | Retried inside the client using a SYSTEM task and verified three Installed states with native DISM plus actual consoles. A module failure is not proof that Windows itself is corrupt. |
| Reading large servicing logs through remote helpers consumed memory | Stopped only the identified lab helpers and switched to bounded tasks and small status files. Collect the smallest diagnostic that answers the question. |
| Password injection and sign-in screen transitions were unreliable | Used guest-scoped administration; a one-use guest logon secret was subsequently removed. No passwords or private setup files were committed. Prefer normal guest sign-in for personal practice. |
| One printer preference refresh reported 0x8007000a | Subsequent policy refreshes and final acceptance showed the printer connected. The historical error is retained; no Point and Print security bypass was introduced. A root-cause fix for that transient error is not claimed. |
| JSON readback unexpectedly included PowerShell provider metadata | Used .NET plain-text reading for the written-file check. Keep evidence small, inspect serialization, and preserve original observations. |

## 12. Repeat verification and understand its limits

On a development machine with the pinned tools, run the offline tests and analyzer as shown in [README validation](../README.md#validation). They mock AD and need no domain. On DC01, run `acceptance/Server.Acceptance.Tests.ps1`; on CLIENT01 **as Alex**, run `scripts/client/Invoke-LabStaffEvidence.ps1 -Step FinalChecks` with guest source and Pester available. The latter records six real client checks.

Final results: **27 offline tests, 10 real server checks and 6 real standard-user client checks passed**. These establish the exercised lab behavior, not production readiness. The [evidence register](../evidence/README.md) links exact results, timestamps and SHA256 manifests. Older installation records remain historical; use the final acceptance files for current completion evidence.

Suggested revisit sequence: explain the architecture without notes; onboard a new fictional user; verify policy and access; resolve one ticket; restore the original state; compare your observations with the captured evidence. Keep your own short incident notes alongside the runbooks.
