# Ticket 01 - Locked-out fictional user

Status: **pending live execution**. Expected results below are acceptance criteria, not observed outcomes.

Scenario: Alex Morgan cannot sign in after repeated incorrect credentials. Scope is `CORP\alex.morgan` in the lab only. Verify the fictional caller's identity before a reset; unlocking should not automatically mean resetting a password.

## Reproduce

First ensure the account is enabled and has completed its first password change. On CLIENT01, sign in as local LabAdmin. Use a secure prompt to supply an intentionally incorrect password for this fictional identity. Never publish the password or credential object.

```powershell
$bad = Get-Credential -UserName 'CORP\alex.morgan' -Message 'Enter an intentionally incorrect lab password'
Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$context = [System.DirectoryServices.AccountManagement.PrincipalContext]::new('Domain','corp.lab')
try {
    1..5 | ForEach-Object { $context.ValidateCredentials('alex.morgan',$bad.GetNetworkCredential().Password) }
} finally { $context.Dispose(); $bad=$null }
```

If the API reports an error instead of false after lockout, stop attempts and inspect the DC. Do not run the loop against any other account/domain.

## Diagnose

On DC01:

```powershell
Get-ADUser alex.morgan -Properties LockedOut,BadPwdCount,LastBadPasswordAttempt |
    Select-Object SamAccountName,Enabled,LockedOut,BadPwdCount,LastBadPasswordAttempt
Get-ADDefaultDomainPasswordPolicy | Select-Object LockoutThreshold,LockoutDuration,LockoutObservationWindow
Get-WinEvent -FilterHashtable @{LogName='Security';Id=4740;StartTime=(Get-Date).AddMinutes(-15)} |
    Select-Object TimeCreated,Id,Message
```

Check the event's account and caller computer. Event availability depends on audit settings and log retention: record that limitation if absent. A disabled account or expired password is a different problem. In production, stale mobile/service credentials can relock an account.

## Fix and verify

```powershell
.\scripts\identity\Unlock-LabUser.ps1 -Identity alex.morgan -WhatIf
.\scripts\identity\Unlock-LabUser.ps1 -Identity alex.morgan
Get-ADUser alex.morgan -Properties LockedOut | Select-Object SamAccountName,LockedOut
```

Use the correct password for one interactive CLIENT01 sign-in. Capture `whoami` in that user session and recheck lockout. Reset only if the scenario requires it, using the password reset helper and a secure prompt; keep password entry out of recordings.

## Prevent

Remove the source of repeated wrong credentials, explain lockout behaviour, and record the cause and verification. Avoid weakening the lockout policy or repeatedly unlocking while failures continue.

## Evidence / observed result

- Before: client sign-in failure or DC lockout state - pending.
- Diagnosis: policy, user properties and matching 4740 event if available - pending.
- After: `LockedOut=False` plus successful fictional-user sign-in - pending.
- Actual commands, timestamps and root cause - pending. Do not mark resolved until these are captured.
