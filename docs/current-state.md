# Deployment state - 21 October 2026 (Australia/Sydney)

Completed on the physical Windows 11 Pro host:

- Downloaded both official Microsoft evaluation ISOs onto H:.
- Created the internal Hyper-V switch, host NAT, and powered-off DC01/CLIENT01 Generation 2 VMs with storage paths on H:.
- Applied the actual Windows Server 2022 Standard Evaluation Core image to DC01's VHDX. DISM reported 100% and success.
- Ran 27 offline Pester tests successfully and obtained zero PSScriptAnalyzer findings. The first published source commit also passed GitHub Actions.

Blocked/unfinished:

- BCDBoot reported `Failure when attempting to copy boot files.` after the Server image applied. The failed attempt stopped before writing guest unattended setup or starting the VM. See the [actual transcript excerpt](../evidence/host/server-image-attempt.txt).
- A repair path now refreshes the EFI partition's drive-letter state, uses the applied Windows image's own BCDBoot with verbose output, and supports `-ResumeAppliedImage` without formatting/reapplying the disk. **The repair has not been verified**: the latest Windows UAC launch was cancelled.
- CLIENT01 has an empty VHDX; Windows 11 is downloaded but not applied. The dedicated backup disk has not yet been added.
- No AD forest, domain join, real identity operations, applied client GPO, RSAT screenshots, worked-ticket outcomes, recovery evidence or demo has been verified. No v1.0.0 release has been published.
- About 4-5 GiB free RAM was available during image preparation. Claude must remain running. The staged workflow can configure DC01 alone with 4 GiB free; starting the 4 GiB client while the DC runs needs 6 GiB free at that point (including 2 GiB host headroom). It does not close applications or reduce client memory below Windows 11 requirements.

To resume safely, use an elevated Windows PowerShell 5.1 window, keep the VMs off for image repair, and retain the existing DPAPI credential files. The ignored local `.lab\resume-prepare-admin.ps1` helper is prepared for this exact state. It repairs the already-applied DC image, installs CLIENT01 to its empty disk, adds the backup VHDX, records inventory/hashes, and then chooses full configuration or DC-only configuration based on free RAM. It preserves partially built disks and writes errors/transcripts under `.lab`.

The underlying tracked repair command, for review before running, is:

```powershell
$dc = Import-Clixml .\.lab\credentials\dc.xml
.\scripts\host\Install-LabGuestImage.ps1 -VMName DC01 `
    -IsoPath "$PWD\.lab\iso\server-2022-eval.iso" -LocalPassword $dc.Password `
    -ResumeAppliedImage -WhatIf
```

Do not rerun Prepare against these existing VMs or delete the applied image to bypass the error. If repair still fails, collect the verbose BCDBoot output and inspect the mounted lab disk's EFI partition/Windows boot source. No successful guest boot is assumed from a DISM success alone.
