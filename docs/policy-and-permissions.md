# Policy and permissions design

OU hierarchy below the domain root:

```text
corp.lab
  Staff / Finance, HR, IT     ordinary fictional user accounts
  Admins                      separate administrative identities (no default staff delegation)
  Computers                   CLIENT01 (DC01 stays in Domain Controllers)
  Disabled                    leavers
  Groups / Finance, HR, IT    global membership and domain-local resource groups
```

Each user is assigned to global `GG_<department>`. That global group is nested in domain-local `DL_<department>_Modify`, which receives the share and NTFS grants (AGDLP: Accounts -> Global -> Domain Local -> Permissions). Users do not receive direct department ACL grants. Administrators and SYSTEM retain Full Control.

| Resource | Share permission | NTFS permission | Expected user result |
| --- | --- | --- | --- |
| `\\DC01\Finance` / F: | DL_Finance_Modify: Change | Same group: Modify, inherited to contents | Finance can create/edit; HR/IT denied |
| `\\DC01\HR` / R: | DL_HR_Modify: Change | Same group: Modify | HR allowed; others denied |
| `\\DC01\IT` / I: | DL_IT_Modify: Change | Same group: Modify | IT allowed; others denied |
| `\\DC01\Homes` / H: user home | Domain Users: Change | Root only: Read/Execute; each child has explicit user SID Modify, SYSTEM/Admins Full | Only the matching user and admins can access each private home |

All four shares enable access-based enumeration and disable offline caching. ABE hides inaccessible children when browsing a share; it does not replace NTFS enforcement and does not necessarily hide share names from server share enumeration. Test direct UNC access too. Onboarding protects home ACL inheritance. New department ACLs are protected from parent inheritance. Existing shares are checked before reuse; inspect their grants on any previously modified lab.

```powershell
Get-SmbShare -Name Finance,HR,IT,Homes | Select-Object Name,Path,FolderEnumerationMode
Get-SmbShareAccess -Name Finance
(Get-Acl C:\LabData\Finance).Access | Format-Table
# In Alex's CLIENT01 session, create/read then remove only your own test file:
whoami /groups
Test-Path \\DC01\Finance
Test-Path \\DC01\HR
```

Policy links created by `Set-LabGroupPolicy.ps1`:

| Policy | Link | Setting |
| --- | --- | --- |
| LAB-Domain-Account-Policy | Domain root | Security template: 14-character minimum, complexity, 24 history, 1/90-day ages, 5 failures, 15-minute lockout/reset; also configured through AD domain policy cmdlet |
| LAB-Security-Baseline | Domain root | LLMNR off; SMB client/server signing required |
| LAB-Windows-Update | Computers OU | Automatic scheduled installation at 03:00; no automatic restart while a user is signed in; no WSUS dependency |
| LAB-Desktop-Restrictions | Staff OU | Control Panel/Settings restriction |
| LAB-Drive-Finance / HR / IT | Staff OU | GPP F:/R:/I: maps, item-level security-group targeting, removal when no longer applied |
| LAB-Printer-Deployment | Staff OU | Shared `\\DC01\LAB-Printer`, no forced default |

Drive and printer preferences are written using Microsoft's [GPP XML schema](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gppref/12512ed6-0632-4e90-a112-d3d2cd41df6c) and [CSE/tool extension identifiers](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gppref/a00e597a-cd21-4a97-9277-f53fae251acf). The script increments user policy versions through a GroupPolicy cmdlet and registers the preference CSE metadata in AD. This is a single-DC lab implementation: verify AD/GPT versions, GPMC interpretation and real client processing before reusing it. Do not edit SYSVOL concurrently in GPMC while running the script.

The virtual print service shares a Generic / Text Only queue on `NUL:`. It proves connection deployment and discards jobs; it is not a physical printer. The client driver is pre-staged as an administrator. Retain Point and Print security protections; if the current Windows build blocks an unprivileged connection, inspect the signed driver and print logs instead of disabling protections. Print Spooler on a DC is a lab-only compromise.

After sign-in as a fictional staff user on CLIENT01:

```powershell
gpupdate /force
gpresult /r
gpresult /h C:\LabEvidence\gpresult-user.html /f
Get-SmbMapping
Get-Printer
Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name NoControlPanel
# In a separate elevated guest session:
gpresult /scope computer /r
Get-ItemProperty 'HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient' -Name EnableMulticast
Get-SmbClientConfiguration | Select-Object RequireSecuritySignature
Get-ItemProperty HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU
```

Changing groups requires a fresh sign-in for the user token. `gpupdate` alone does not refresh all Kerberos/group token state. User GPOs follow the user OU; computer GPOs follow the computer OU. A successful `gpupdate` exit code alone does not prove the intended settings or printer/drive succeeded. Capture effective settings and actual behaviour. Windows Update policy reporting can vary by client version; record build and observable update behaviour, without claiming a completed update cycle merely from registry values.
