# Ticket 04 - Computer trust relationship failure

Status: **pending live execution**. This fault injection is limited to the disposable CLIENT01 machine account.

## Reproduce

Ensure you can sign in as **CLIENT01\LabAdmin** and retain its DPAPI-protected credential before introducing the fault. On DC01, reset only the directory-side password for `CLIENT01$`, using a temporary SecureString. This deliberately desynchronises the machine password from the client; never run against another computer.

```powershell
$temporaryMachinePassword = Read-Host 'Temporary fictional machine password' -AsSecureString
Set-ADAccountPassword -Identity 'CLIENT01$' -Reset -NewPassword $temporaryMachinePassword
```

Restart only CLIENT01. A domain sign-in or secure-channel test should now fail; capture the actual result. If the channel still works because of timing/cached state, document the observation and investigate instead of inventing a failure or rolling back the DC.

## Diagnose

Sign in locally on CLIENT01 and open an elevated guest PowerShell session:

```powershell
Get-CimInstance Win32_ComputerSystem | Select-Object Name,Domain,PartOfDomain
Get-DnsClientServerAddress -AddressFamily IPv4
Resolve-DnsName _ldap._tcp.dc._msdcs.corp.lab -Type SRV -Server 192.168.77.10
w32tm /query /status
Test-ComputerSecureChannel -Verbose
Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='NETLOGON';StartTime=(Get-Date).AddMinutes(-30)} |
    Select-Object TimeCreated,Id,Message
```

Distinguish DNS/DC availability, clock skew, disabled/missing machine account and a mismatched machine secret. A ping response does not establish domain authentication. This repair command is for member clients, not a DC.

## Fix and verify

```powershell
$repairCredential = Get-Credential 'CORP\Administrator'
Test-ComputerSecureChannel -Repair -Server DC01.corp.lab -Credential $repairCredential -Verbose
Test-ComputerSecureChannel -Verbose
gpupdate /force
```

Restart CLIENT01 if required and sign in as the fictional domain user. Confirm `Test-ComputerSecureChannel=True`, successful domain logon and policy processing. Do not remove/rejoin the computer as the first response when a scoped secure-channel repair suffices. Keep the local recovery account available.

## Prevent

Avoid reverting domain members to old snapshots, duplicate computer names and uncontrolled machine account resets. Use supported backups and document credential/identity changes. Never roll a DC back casually to fix one client.

## Evidence / observed result

- Before: actual trust error / false secure-channel result - pending.
- Diagnosis: DNS/time/account checks plus relevant NETLOGON event - pending.
- After: repair output, true channel and successful domain-user sign-in - pending.
- Commands, exact fault cause and timestamps - pending.
