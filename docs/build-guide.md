# Build guide

Run host commands from an elevated **Windows PowerShell 5.1** window in the repository. The Hyper-V service must be installed/running and firmware virtualisation enabled. This lab targets Windows 11 Pro or Enterprise as the host; it does not enable Hyper-V or reboot the physical PC automatically.

1. Keep all lab files on H:. Allow at least 65 GiB free **after** the roughly 13 GiB of ISO downloads. The 60 GiB DC OS, 80 GiB client OS and 40 GiB backup disks are dynamic maxima, not reserved capacity. Their combined maximum exceeds the currently available H: space: monitor physical free space, keep 35 GiB headroom and expand/move storage before the disks grow. Disable automatic checkpoints; avoid saved states and ISO extraction to C:.
2. Download [Server 2022 evaluation](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022) and [Windows 11 Enterprise evaluation](https://www.microsoft.com/en-us/evalcenter/download-windows-11-enterprise) from Microsoft. The official English US download links used for this build are [Server](https://go.microsoft.com/fwlink/p/?LinkID=2195280&clcid=0x409&country=US&culture=en-us) and [Enterprise](https://go.microsoft.com/fwlink/?LinkId=2382600&clcid=0x409&country=us&culture=en-us); Microsoft can change their targets. A filename or a locally calculated hash alone is not independent authenticity verification. Compare Microsoft-published hashes where available, record the final resolved URL and image metadata, and inspect the installed evaluation edition.
3. Place them at `.lab\iso\server-2022-eval.iso` and `.lab\iso\windows-11-enterprise-eval.iso`. Never add ISOs or VHDX files to Git.
4. Check `192.168.77.0/24` does not overlap your LAN/VPN/other virtual networks. `Get-NetRoute -AddressFamily IPv4` and `Get-NetIPAddress -AddressFamily IPv4` help. If it overlaps, change every configured lab address consistently before provisioning. Existing unrelated WinNAT rules cause the script to stop for inspection.

```powershell
Get-VM
Get-VMSwitch
Get-NetNat
Get-NetRoute -AddressFamily IPv4
.\scripts\host\Invoke-LabBuild.ps1 -Stage Prepare -WhatIf
.\scripts\host\Invoke-LabBuild.ps1 -Stage Prepare
```

Prepare makes an internal switch/NAT, empty Gen 2 VMs, Secure Boot and local-key-protected vTPM. It mounts only the new lab VHDX files, verifies RAW disk state, then creates EFI/MSR/OS partitions. DISM applies Server Standard Evaluation Core and Windows 11 Enterprise Evaluation. BCDBoot supplies UEFI boot files. Guest names, local accounts, locale and timezone are supplied in an unattended setup file inside the ignored VHDX. That file contains encoded credentials: treat the whole VHDX as secret. It is never copied to the public repository. No product keys are supplied. The lab does not add Windows Recovery partitions.

Random passwords are DPAPI-encrypted in `.lab\credentials\{dc,client,dsrm}.xml`, with an explicit local ACL. Only the same Windows user on the same host can normally decrypt them. They do not need to be typed into chat. Do not share or publish these files. Back up credentials securely if keeping the lab long term.

```powershell
# Verify on the host (select only these two lab VMs):
Get-VM -Name DC01,CLIENT01 | Select-Object Name,State,Generation,Path,SnapshotFileLocation,SmartPagingFilePath
Get-VMHardDiskDrive -VMName DC01,CLIENT01 | Select-Object VMName,Path
Get-VMFirmware -VMName DC01,CLIENT01 | Select-Object VMName,SecureBoot
Get-VMSecurity -VMName DC01,CLIENT01 | Select-Object VMName,TpmEnabled

# Need >=8 GiB free RAM. The physical host is never rebooted by Configure.
.\scripts\host\Invoke-LabBuild.ps1 -Stage Configure -WhatIf
.\scripts\host\Invoke-LabBuild.ps1 -Stage Configure
```

If other applications must stay open, configure only DC01 first with `-Stage ConfigureDC` (4 GiB free RAM for its 2 GiB startup plus host headroom). After that stage succeeds, use `-Stage ConfigureClient` when there is enough RAM for the stopped client plus 2 GiB host headroom. Keep DC01 running for client domain join and GPO. `Start-Lab.ps1` counts only powered-off requested VMs; it never closes applications or reduces Windows 11's 4 GiB minimum. A staged DC build is not proof of a completed client lab.

Configure starts the guests, waits for PowerShell Direct, copies only lab source/data, promotes DC01 (guest restart), configures AD/DNS/DHCP, shares, a virtual print queue and GPOs, then joins CLIENT01 (guest restart) and installs RSAT. It uses Windows Update over NAT for capabilities. Promotion/join disconnects may be reported during expected guest restarts; inspect the guest before retrying. If first boot pauses in Windows setup, use VMConnect to inspect the exact screen and Panther setup logs. Do not bypass licence or security prompts blindly.

Manual work is limited to Microsoft evaluation registration/licence review if prompted, host UAC approval, resolving host-specific prerequisites/conflicts, and interactive sign-in/console screenshots. The offline image path normally avoids interactive setup. If the particular evaluation build rejects the unattended file, inspect `C:\Windows\Panther\setuperr.log` in that guest and repair the configuration; do not claim a successful installation while OOBE is incomplete.

For manual recovery from a partial Configure, use individual scripts inside the guests rather than rerunning Prepare:

If image application succeeded but boot/setup configuration did not, `Install-LabGuestImage.ps1 -ResumeAppliedImage` validates the existing labelled GPT lab partitions and Windows SYSTEM hive, then retries boot/unattended setup. It never formats/reapplies in that mode. This repair path requires integration verification; see [current state](current-state.md) for the actual machine's blocker.

```powershell
# Host -> DC01 with the local/domain admin password protected on this host:
$local = Import-Clixml .\.lab\credentials\dc.xml
$domain = [pscredential]::new('CORP\Administrator', $local.Password)
$dc = New-PSSession -VMName DC01 -Credential $domain
Invoke-Command -Session $dc { Get-ADDomain; Get-Service ADWS,DNS,DHCPServer }
Remove-PSSession $dc
```

Use `Enter-PSSession -VMName CLIENT01 -Credential (Import-Clixml .\.lab\credentials\client.xml)` for an existing client local admin session. Windows PowerShell Direct needs neither WinRM exposure nor host NIC access to the guest. Interactive console sign-in is a user action; never save credentials into screenshots or command history.

After first boot, review and remove cached unattend files in the guests if setup has not already scrubbed them; keep deletion scoped to the exact known setup files after checking setup is finished. The VHDX and local credential directory remain sensitive regardless.

Validation gates before portfolio completion:

- Guest editions are ServerStandardEval and EnterpriseEval; record expiry, time sync and Windows Update state.
- `dcdiag`, AD services, DNS SRV, DHCP lease, domain membership and secure channel pass.
- Onboard fictional users, test access as each user, capture policy and RSAT evidence.
- Execute all five tickets and recovery demonstration, then capture the 30-90 second demo.
- Review evidence for secrets, run analysis/Pester, publish and verify green CI before the final release.

Optional real integration acceptance uses Pester 5.7.1 from `acceptance/`, deliberately outside the CI `tests/` path. Copy that folder into the guests and run `Invoke-Pester -Path .\acceptance\Server.Acceptance.Tests.ps1` on DC01. Run the client file as `CORP\alex.morgan` after onboarding and first-password change. These tests inspect actual services and policy; they are not mocked and must never be reported as passed unless executed. Test after restoring all injected ticket faults and before offboarding Alex.

Shut down the guests normally to return RAM. No automated teardown script deletes VMs/disks: retain backups and evidence, inspect exact paths, then remove only named lab resources if you choose to retire the lab. The lab NAT/switch are explicitly named `WindowsADLab-NAT` and `WindowsADLab-Internal`.
