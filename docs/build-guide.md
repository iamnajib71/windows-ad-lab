# Build guide

Use elevated **Windows PowerShell 5.1** for Hyper-V management. The host needs Windows 11 Pro/Enterprise, enabled firmware virtualisation and Hyper-V. Scripts never reboot the physical PC or change its page file/boot configuration. All large files live under `H:\My Projects - IT\windows-ad-lab\.lab`.

## Storage and media

Allow 65 GiB free after the roughly 13 GiB of ISO downloads. The 60 GiB DC OS, 80 GiB client OS and 40 GiB backup disks are dynamic maxima, not reserved space. Their combined maximum exceeds the current free H: capacity: keep 35 GiB headroom and expand/move storage before disks grow. Automatic checkpoints are disabled; paging/checkpoint paths point to H:.

DC01 has a 2 GiB RAM cap and CLIENT01 a 4 GiB cap. Both stopped VMs require at least 8 GiB free on the host, including 2 GiB headroom. On a constrained host, boot Windows Setup in one guest at a time with `Start-Lab.ps1 -VMName`; gracefully shut down the other guest first. Both guests must be running for domain join and policy verification. Guest Windows paging stays inside the virtual disks on H:.

Download [Server 2022 evaluation](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022) and [Windows 11 Enterprise evaluation](https://www.microsoft.com/en-us/evalcenter/download-windows-11-enterprise). Save as `.lab\iso\server-2022-eval.iso` and `.lab\iso\windows-11-enterprise-eval.iso`. The English-US links used are [Server](https://go.microsoft.com/fwlink/p/?LinkID=2195280&clcid=0x409&country=US&culture=en-us) and [Enterprise](https://go.microsoft.com/fwlink/?LinkId=2382600&clcid=0x409&country=us&culture=en-us); their targets may change. Compare Microsoft-published hashes where available; a locally generated hash alone is not independent authenticity verification. Record installed evaluation editions and expiry.

Check `192.168.77.0/24` does not overlap LAN/VPN/other virtual networks using `Get-NetRoute -AddressFamily IPv4` and `Get-NetIPAddress -AddressFamily IPv4`. Change every lab address consistently if needed. Existing unrelated WinNAT configurations cause a stop for inspection. `config/lab.psd1` is a reference inventory; scripts contain explicit lab defaults.

Prepare also needs the free [official 7-Zip archive tool](https://www.7-zip.org/download.html), placed at `.tools\7zip\portable\7z.exe` with its matching DLL. `Export-LabPrinterPackage.ps1` extracts ordinary files on H: to obtain the original Microsoft Generic/Text driver and catalog from image 2 (Desktop Experience) of the same Server evaluation ISO. The package stays ignored under `.lab\drivers\GenericTextOnly`; no Windows binaries are committed. PnPUtil verifies and stages it inside each guest, then the print driver is registered there. The real catalog check returned a valid Microsoft Windows signature. WIM extraction adds roughly 4 GiB of temporary storage on H:.

## Guest-only installation

```powershell
Get-VM
Get-VMSwitch
Get-NetNat
.\scripts\host\Invoke-LabBuild.ps1 -Stage Prepare -WhatIf
.\scripts\host\Invoke-LabBuild.ps1 -Stage Prepare
```

Prepare creates the network, blank Gen 2 VMs, local-key-protected vTPM and Secure Boot. Random credentials are DPAPI-protected in `.lab\credentials\{dc,client,dsrm}.xml` with a local ACL. Only the same Windows user on the same host can normally decrypt them. No product keys are supplied.

`New-LabSetupMedia.ps1` creates a small **data ISO on H:** containing Autounattend.xml through Windows IMAPI. This ISO/source folder contain encoded passwords, which remain secrets. Both are ignored and ACL-protected. The official bootable Windows ISO is attached separately. Windows Setup runs inside the VM; the host only reads the ISO archive to obtain the printer package described above.

Windows Setup searches removable read-only media for an answer file ([Microsoft reference](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-setup-automation-overview?view=windows-11)). The answer file selects evaluation image index 1, guest name/locale/account, and guest disk 0 / partition 3. Media creation requires exactly one lab OS VHDX at virtual SCSI 0:0, detached from the host. The backup disk is added after DC OS installation.

**Setup replaces the guest OS disk. Never attach physical/pass-through disks, unrelated VHDX files or non-lab data to these VMs.** Current host scripts do not mount VHDX files, run boot repair, repartition physical disks, invoke the host Windows installer, modify host firmware boot order or move its page file. The earlier host-side image approach was retired after a boot-store error; its actual failure remains in the evidence.

```powershell
# Both stopped VMs need 8 GiB free: 6 GiB startup + 2 GiB host headroom.
.\scripts\host\Invoke-LabBuild.ps1 -Stage Configure -WhatIf
.\scripts\host\Invoke-LabBuild.ps1 -Stage Configure
# Or DC01 only first, requiring 4 GiB free:
.\scripts\host\Invoke-LabBuild.ps1 -Stage ConfigureDC
# After DCConfigured, when enough RAM is free:
.\scripts\host\Invoke-LabBuild.ps1 -Stage ConfigureClient
```

Start-Lab counts only stopped requested VMs. It sends one Space through Hyper-V's virtual keyboard after startup for the DVD prompt; it does not type into the physical desktop. If it misses the prompt, press a boot key in VMConnect. Inspect setup errors rather than assuming a running VM is installed.

Configure waits up to an hour per first-boot PowerShell Direct session, promotes DC01 (guest restart), configures AD/DNS/DHCP/shares/policy/print queue, joins CLIENT01 (guest restart) and installs RSAT. Capabilities need outbound Internet via NAT. Install current Windows servicing updates in both guests before treating the focused baseline as validated.

Manual actions are evaluation registration/licence review if prompted, UAC approval, resource/network conflicts, setup prompts not handled by the answer file, interactive user sign-in and console evidence. Do not bypass authentication/security/licence prompts. Inspect guest Panther errors before changing setup. DC01 reached a verified domain-controller state on the downloaded build; client setup and sign-in remain pending.

## Inspect and recover partial builds

```powershell
Get-VM -Name DC01,CLIENT01 | Select-Object Name,State,Generation,Path,SnapshotFileLocation,SmartPagingFilePath
Get-VMHardDiskDrive -VMName DC01,CLIENT01 | Select-Object VMName,Path
Get-VMFirmware -VMName DC01,CLIENT01 | Select-Object VMName,SecureBoot
Get-VMSecurity -VMName DC01,CLIENT01 | Select-Object VMName,TpmEnabled
$local = Import-Clixml .\.lab\credentials\dc.xml
$domain = [pscredential]::new('CORP\Administrator', $local.Password)
$dc = New-PSSession -VMName DC01 -Credential $domain
Invoke-Command -Session $dc { Get-ADDomain; Get-Service ADWS,DNS,DHCPServer }
Remove-PSSession $dc
```

Resume individual guest scripts only after checking actual state. Do not rerun Prepare against existing VMs or replace credentials. Cached answer files/private setup ISOs remain sensitive: inspect/scrub after setup finishes, retaining credentials securely. PowerShell Direct needs no WinRM exposure or second DC NIC.

Completion requires editions/expiry, DC health, DNS/DHCP, domain membership, secure channel, actual identity operations, user/computer GPOs, RSAT screenshots, positive/negative file access, five worked tickets, Recycle Bin restore, System State backup and a real demo. Optional Pester files in `acceptance/` are outside CI: copy into the guests and run the server file on DC01 and client file as CORP\alex.morgan after first password change and before offboarding.

Shut down guests normally. Teardown is manual: inspect exact paths and preserve evidence/backups before deleting named lab resources. Switch/NAT names are `WindowsADLab-Internal` and `WindowsADLab-NAT`. Checkpoints are not backups.
