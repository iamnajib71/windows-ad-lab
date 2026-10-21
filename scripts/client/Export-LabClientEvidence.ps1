[CmdletBinding(SupportsShouldProcess)]
param([string]$OutputDirectory='C:\LabEvidence')
$ErrorActionPreference='Stop'
if ($env:COMPUTERNAME -ne 'CLIENT01') { throw 'Run inside CLIENT01 only.' }
if ($PSCmdlet.ShouldProcess($OutputDirectory,'Capture actual domain, policy, network, RSAT and SMB results')) {
    $null=New-Item -ItemType Directory -Path $OutputDirectory -Force
    $computer=Get-CimInstance Win32_ComputerSystem | Select-Object Name,Domain,PartOfDomain
    $computer | ConvertTo-Json | Set-Content (Join-Path $OutputDirectory 'domain.json')
    & gpresult.exe /h (Join-Path $OutputDirectory 'gpresult.html') /f
    if ($LASTEXITCODE -ne 0) { throw 'gpresult failed; run as the fictional lab user, elevated if collecting computer policy.' }
    & gpresult.exe /r | Out-File (Join-Path $OutputDirectory 'gpresult.txt')
    Get-DnsClientServerAddress -AddressFamily IPv4 | Format-List | Out-File (Join-Path $OutputDirectory 'dns.txt')
    Get-SmbMapping | Format-List | Out-File (Join-Path $OutputDirectory 'mappings.txt')
    Get-Printer | Select-Object Name,Type,DriverName | Export-Csv (Join-Path $OutputDirectory 'printers.csv') -NoTypeInformation
    Get-WindowsCapability -Online -Name 'Rsat*' | Where-Object State -eq Installed | Select-Object Name,State | Export-Csv (Join-Path $OutputDirectory 'rsat.csv') -NoTypeInformation
    Get-SmbClientConfiguration | Select-Object RequireSecuritySignature | ConvertTo-Json | Set-Content (Join-Path $OutputDirectory 'smb-client.json')
    Get-ItemProperty 'HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient' -Name EnableMulticast | Select-Object EnableMulticast | ConvertTo-Json | Set-Content (Join-Path $OutputDirectory 'llmnr.json')
    Get-ChildItem -LiteralPath $OutputDirectory -File | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv (Join-Path $OutputDirectory 'SHA256SUMS.csv') -NoTypeInformation
}
