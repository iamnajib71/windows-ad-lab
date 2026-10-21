# Ticket 05 - User cannot access a department share

Status: **pending live execution**. Scenario: Alex is correctly in Finance but cannot access the Finance share.

## Reproduce

Capture the known-good share/NTFS ACLs first. On DC01 temporarily revoke only the Finance domain-local share grant:

```powershell
Get-SmbShareAccess -Name Finance
(Get-Acl C:\LabData\Finance).Access | Format-Table
Revoke-SmbShareAccess -Name Finance -AccountName 'CORP\DL_Finance_Modify' -Force
```

Sign Alex out/in on CLIENT01 to avoid an existing SMB session masking the change. Try `\\DC01\Finance`; capture the actual denial or error. This lab-only fault affects all fictional Finance users until restored.

## Diagnose

```powershell
# Alex's CLIENT01 session:
whoami /groups
Get-SmbMapping
Test-NetConnection DC01 -Port 445
Get-ChildItem \\DC01\Finance
# DC01 lab admin:
Get-ADPrincipalGroupMembership alex.morgan | Select-Object Name
Get-ADGroupMember DL_Finance_Modify | Select-Object Name
Get-SmbShareAccess Finance
(Get-Acl C:\LabData\Finance).Access | Format-Table IdentityReference,FileSystemRights,AccessControlType,IsInherited
Get-SmbSession | Select-Object ClientComputerName,ClientUserName,NumOpens
```

Confirm the intended AGDLP chain, current token, SMB reachability, share grant and NTFS grant. Effective network access is limited by both share and NTFS permissions; explicit deny entries can override allows. In this injected fault, the missing share grant should be the cause, while NTFS and membership remain correct. Record any deviation.

## Fix and verify

```powershell
# DC01 lab admin - restore exactly the intended group grant:
Grant-SmbShareAccess -Name Finance -AccountName 'CORP\DL_Finance_Modify' -AccessRight Change -Force
Get-SmbShareAccess Finance
# Alex's fresh CLIENT01 user session:
$testFile='\\DC01\Finance\ticket05-alex-test.txt'
'Fictional lab access test' | Set-Content -LiteralPath $testFile
Get-Content -LiteralPath $testFile
Test-Path \\DC01\HR
```

Capture successful Finance create/read, HR denial, and private home isolation (another user's home must be denied). Delete only your own named test file after evidence review. Do not grant Everyone Full Control or add the staff user to Administrators to solve access problems.

## Prevent

Maintain resource permissions on domain-local groups, review ACLs against declared state, and test both allowed and denied users after changes. ABE improves browsing but is not an authorisation boundary. Document root cause rather than treating every denial as a group membership problem.

## Evidence / observed result

- Before: Alex's access denied plus share grant missing - pending.
- Diagnosis: intact group/NTFS chain and SMB reachability - pending.
- After: restored group share grant, Finance file access and negative HR/home tests - pending.
- Actual commands, timestamps and closure notes - pending.
