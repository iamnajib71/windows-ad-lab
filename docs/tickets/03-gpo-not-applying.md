# Ticket 03 - Desktop GPO not applying

Status: **pending live execution**. Intended acceptance: restore the scoped policy and verify the effective restriction in the staff session.

## Reproduce

From a lab admin session, temporarily disable only the Staff link for the desktop restriction:

```powershell
Set-GPLink -Name LAB-Desktop-Restrictions -Target 'OU=Staff,DC=corp,DC=lab' -LinkEnabled No
```

In Alex's CLIENT01 session run `gpupdate /target:user /force`, then sign out/in if needed. Record whether Control Panel/Settings becomes available and whether `NoControlPanel` is removed. Do not assume a previous setting has been cleared without checking.

## Diagnose

```powershell
# Alex's user session on CLIENT01:
gpresult /r
gpresult /scope user /v
gpresult /h C:\LabEvidence\ticket03-before.html /f
Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name NoControlPanel -ErrorAction SilentlyContinue
Resolve-DnsName _ldap._tcp.dc._msdcs.corp.lab -Type SRV
```

From lab admin RSAT, verify Alex's distinguished name is under Staff, inspect `Get-GPInheritance -Target 'OU=Staff,DC=corp,DC=lab'`, the link enabled state, security filtering, delegation Read permissions, WMI filters and GroupPolicy Operational log. Explain which finding proves the cause. A policy absent from scope differs from a policy denied by filtering or a preference extension failure.

## Fix and verify

```powershell
# Lab admin:
Set-GPLink -Name LAB-Desktop-Restrictions -Target 'OU=Staff,DC=corp,DC=lab' -LinkEnabled Yes
# Alex's CLIENT01 session:
gpupdate /target:user /force
gpresult /r
gpresult /h C:\LabEvidence\ticket03-after.html /f
Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name NoControlPanel
```

Show the policy in Applied GPOs, the effective value of 1, and the actual restriction when opening Control Panel. For computer policies use a separate elevated `/scope computer` report. Save actual `gpupdate` output including any warnings.

## Prevent

Check enabled links and intended OU scope as part of a change review. Test standard users separately from administrators. Preserve before/after reports and link configuration; do not solve a user scope problem by enabling loopback or moving policies to the domain root indiscriminately.

## Evidence / observed result

- Before: missing applied policy and unrestricted behaviour - pending.
- Diagnosis: disabled Staff link in GPMC / inheritance output - pending.
- After: applied policy, `gpupdate`, effective value and restriction - pending.
- Actual root cause, timestamps and reports - pending.
