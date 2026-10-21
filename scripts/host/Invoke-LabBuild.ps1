#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param(
    [ValidateSet('Prepare','Configure')][string]$Stage='Prepare',
    [string]$LabRoot='H:\My Projects - IT\windows-ad-lab\.lab'
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$LabRoot=[IO.Path]::GetFullPath($LabRoot)
if ([IO.Path]::GetPathRoot($LabRoot) -eq 'C:\') { throw 'Lab storage must be on a data drive.' }
if (-not $PSCmdlet.ShouldProcess("$Stage / $LabRoot",'Build evaluation AD lab (guest restarts during Configure)')) { return }
$null=New-Item -ItemType Directory -Path $LabRoot -Force
function Get-LabSecret {
    $bytes=New-Object byte[] 30
    $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    $secret=[securestring]::new()
    foreach ($character in ('Aa1!'+[Convert]::ToBase64String($bytes)).ToCharArray()) { $secret.AppendChar($character) }
    $secret.MakeReadOnly()
    $secret
}
function Open-LabSession {
    param([string]$Name,[pscredential]$Credential,[int]$TimeoutSeconds=1200)
    $deadline=(Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try { return New-PSSession -VMName $Name -Credential $Credential -ErrorAction Stop }
        catch { Start-Sleep -Seconds 10 }
    }
    throw "PowerShell Direct did not become ready on $Name within $TimeoutSeconds seconds. Inspect VMConnect and guest setup logs."
}
function Copy-LabSource {
    param($Session)
    Invoke-Command -Session $Session { $null=New-Item -ItemType Directory -Path C:\LabRepo -Force }
    foreach ($folder in @('scripts','src','data','config')) {
        Copy-Item -LiteralPath (Join-Path $repo $folder) -Destination C:\LabRepo -ToSession $Session -Recurse -Force
    }
}
if ($Stage -eq 'Prepare') {
    $serverIso=Join-Path $LabRoot 'iso\server-2022-eval.iso'
    $clientIso=Join-Path $LabRoot 'iso\windows-11-enterprise-eval.iso'
    foreach ($iso in @($serverIso,$clientIso)) {
        if (-not (Test-Path $iso) -or (Get-Item $iso).Length -lt 4GB) { throw 'Both official ISO downloads must be complete first.' }
        $stream=$null
        try { $stream=[IO.File]::Open($iso,'Open','Read','None') }
        catch { throw 'An ISO is still open, possibly being downloaded. Wait for the download to finish.' }
        finally { if ($stream) { $stream.Dispose() } }
    }
    if ((Get-PSDrive -Name ([IO.Path]::GetPathRoot($LabRoot).Substring(0,1))).Free -lt 65GB) { throw 'Need at least 65 GiB free after ISO downloads for the initial installation and backup headroom.' }
    $secretPath=Join-Path $LabRoot 'credentials'
    $null=New-Item -ItemType Directory -Path $secretPath -Force
    $acl=[Security.AccessControl.DirectorySecurity]::new()
    $acl.SetAccessRuleProtection($true,$false)
    foreach ($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18','S-1-5-32-544')) {
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
    }
    Set-Acl -LiteralPath $secretPath -AclObject $acl
    if (Get-ChildItem -LiteralPath $secretPath -File) { throw 'Credentials already exist; inspect previous build before replacing them.' }
    $serverCredential=[pscredential]::new('Administrator',(Get-LabSecret))
    $clientCredential=[pscredential]::new('LabAdmin',(Get-LabSecret))
    $dsrmCredential=[pscredential]::new('DSRM',(Get-LabSecret))
    $serverCredential | Export-Clixml (Join-Path $secretPath 'dc.xml')
    $clientCredential | Export-Clixml (Join-Path $secretPath 'client.xml')
    $dsrmCredential | Export-Clixml (Join-Path $secretPath 'dsrm.xml')
    & "$PSScriptRoot\New-LabVMs.ps1" -LabRoot $LabRoot -ServerIso $serverIso -ClientIso $clientIso
    & "$PSScriptRoot\Install-LabGuestImage.ps1" -VMName DC01 -IsoPath $serverIso -LocalPassword $serverCredential.Password -LabRoot $LabRoot -Confirm:$false
    & "$PSScriptRoot\Install-LabGuestImage.ps1" -VMName CLIENT01 -IsoPath $clientIso -LocalPassword $clientCredential.Password -LabRoot $LabRoot -Confirm:$false
    & "$PSScriptRoot\Add-LabBackupDisk.ps1" -LabRoot $LabRoot
    Get-FileHash -LiteralPath $serverIso,$clientIso -Algorithm SHA256 | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv (Join-Path $LabRoot 'iso-sha256.csv') -NoTypeInformation
    'Prepared' | Set-Content (Join-Path $LabRoot 'build-stage.txt')
    return
}
if (-not (Test-Path (Join-Path $LabRoot 'build-stage.txt'))) { throw 'Complete Prepare first.' }
if ((Get-Content (Join-Path $LabRoot 'build-stage.txt') -Raw).Trim() -ne 'Prepared') { throw 'Configuration has already started; inspect progress before retrying.' }
& "$PSScriptRoot\Start-Lab.ps1"
'Configuring - inspect logs before rerunning' | Set-Content (Join-Path $LabRoot 'build-stage.txt')
$dcCredential=Import-Clixml (Join-Path $LabRoot 'credentials\dc.xml')
$clientCredential=Import-Clixml (Join-Path $LabRoot 'credentials\client.xml')
$dsrm=Import-Clixml (Join-Path $LabRoot 'credentials\dsrm.xml')
$session=Open-LabSession DC01 $dcCredential
try {
    Copy-LabSource $session
    $dsrmPassword=$dsrm.Password
    Invoke-Command -Session $session {
        & C:\LabRepo\scripts\server\Install-LabForest.ps1 -DSRMPassword $using:dsrmPassword -Confirm:$false
    }
} finally { Remove-PSSession $session }
# Wait for the promotion-triggered restart before reconnecting.
Start-Sleep -Seconds 60
$domainCredential=[pscredential]::new('CORP\Administrator',$dcCredential.Password)
$session=Open-LabSession DC01 $domainCredential
try {
    Invoke-Command -Session $session {
        $ErrorActionPreference='Stop'
        & C:\LabRepo\scripts\server\Initialize-LabDomain.ps1 -Confirm:$false
        & C:\LabRepo\scripts\server\Initialize-LabShares.ps1
        & C:\LabRepo\scripts\server\Initialize-LabPrinter.ps1
        & C:\LabRepo\scripts\server\Set-LabGroupPolicy.ps1
        & C:\LabRepo\scripts\server\Initialize-LabBackupDisk.ps1 -Confirm:$false
    }
} finally { Remove-PSSession $session }
$session=Open-LabSession CLIENT01 $clientCredential
try {
    Copy-LabSource $session
    Invoke-Command -Session $session {
        & C:\LabRepo\scripts\client\Join-LabDomain.ps1 -DomainCredential $using:domainCredential -Confirm:$false
    }
} finally { Remove-PSSession $session }
Start-Sleep -Seconds 60
$session=Open-LabSession CLIENT01 $clientCredential
try {
    Invoke-Command -Session $session {
        & C:\LabRepo\scripts\client\Install-LabRSAT.ps1
        # Pre-stage the inbox driver as an administrator; retain Point and Print protections.
        Add-PrinterDriver -Name 'Generic / Text Only'
        gpupdate.exe /force
        Get-CimInstance Win32_ComputerSystem | Select-Object Name,Domain,PartOfDomain
    }
} finally { Remove-PSSession $session }
'DomainConfigured - tickets, printer, backup, recovery and user evidence still pending' | Set-Content (Join-Path $LabRoot 'build-stage.txt')
