#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param(
    [ValidateSet('Prepare','Configure','ConfigureDC','ConfigureClient')][string]$Stage='Prepare',
    [string]$LabRoot='H:\My Projects - IT\windows-ad-lab\.lab',
    [switch]$ResumeClient
)
$ErrorActionPreference='Stop'
if ($ResumeClient -and $Stage -ne 'ConfigureClient') { throw 'ResumeClient is supported only with ConfigureClient.' }
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
    param([string]$Name,[pscredential]$Credential,[int]$TimeoutSeconds=3600,[datetime]$BootAfter=[datetime]::MinValue)
    $deadline=(Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $candidate=$null
        try {
            $candidate=New-PSSession -VMName $Name -Credential $Credential -ErrorAction Stop
            $minimumBootTime=$BootAfter
            $setupComplete=Invoke-Command -Session $candidate {
                $setup=Get-ItemProperty 'HKLM:\SYSTEM\Setup'
                $image=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State'
                [int]$setup.SystemSetupInProgress -eq 0 -and [int]$setup.OOBEInProgress -eq 0 -and $image.ImageState -eq 'IMAGE_STATE_COMPLETE' -and (Get-CimInstance Win32_OperatingSystem).LastBootUpTime -gt $using:minimumBootTime
            }
            if ($setupComplete) {
                # Limit the execution-policy allowance to this guest session.
                Invoke-Command -Session $candidate { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force }
                return $candidate
            }
        } catch { Write-Verbose "Waiting for $Name Windows setup and PowerShell Direct." }
        if ($candidate) { Remove-PSSession $candidate -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 10
    }
    throw "PowerShell Direct did not become ready on $Name within $TimeoutSeconds seconds. Inspect VMConnect and guest setup logs."
}
function Copy-LabSource {
    param($Session)
    Invoke-Command -Session $Session { $null=New-Item -ItemType Directory -Path C:\LabRepo -Force }
    foreach ($folder in @('scripts','src','data','config')) {
        Copy-Item -LiteralPath (Join-Path $repo $folder) -Destination C:\LabRepo -ToSession $Session -Recurse -Force
    }
    $printerPackage=Join-Path $LabRoot 'drivers\GenericTextOnly'
    if (-not (Test-Path -LiteralPath (Join-Path $printerPackage 'prnge001.inf'))) { throw 'Extract the signed evaluation-media printer package first; see the build guide.' }
    Invoke-Command -Session $Session { $null=New-Item -ItemType Directory -Path C:\LabDrivers -Force }
    Copy-Item -LiteralPath $printerPackage -Destination C:\LabDrivers -ToSession $Session -Recurse -Force
}
function Remove-LabSetupDrive {
    [CmdletBinding(SupportsShouldProcess)]
    param([ValidateSet('DC01','CLIENT01')][string]$Name)
    # Run only after PowerShell Direct proves Windows has finished first boot.
    # Removing both virtual optical drives also frees guest drive letters for backup.
    foreach ($drive in @(Get-VMDvdDrive -VMName $Name)) {
        if ($PSCmdlet.ShouldProcess($Name,'Remove virtual setup DVD drive')) {
            Remove-VMDvdDrive -VMDvdDrive $drive -Confirm:$false
        }
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
    & "$PSScriptRoot\Export-LabPrinterPackage.ps1" -LabRoot $LabRoot
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
    & "$PSScriptRoot\New-LabSetupMedia.ps1" -VMName DC01 -LocalPassword $serverCredential.Password -LabRoot $LabRoot -Confirm:$false
    & "$PSScriptRoot\New-LabSetupMedia.ps1" -VMName CLIENT01 -LocalPassword $clientCredential.Password -LabRoot $LabRoot -Confirm:$false
    Get-FileHash -LiteralPath $serverIso,$clientIso -Algorithm SHA256 | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv (Join-Path $LabRoot 'iso-sha256.csv') -NoTypeInformation
    'Prepared' | Set-Content (Join-Path $LabRoot 'build-stage.txt')
    return
}
if (-not (Test-Path (Join-Path $LabRoot 'build-stage.txt'))) { throw 'Complete Prepare first.' }
$state=(Get-Content (Join-Path $LabRoot 'build-stage.txt') -Raw).Trim()
$expected=if ($Stage -eq 'ConfigureClient') { 'DCConfigured' } else { 'Prepared' }
if ($ResumeClient) { $expected='Configuring - inspect logs before rerunning' }
if ($state -ne $expected) { throw "Expected stage $expected but found $state; inspect progress before retrying." }
if ($Stage -eq 'ConfigureDC') { & "$PSScriptRoot\Start-Lab.ps1" -VMName DC01 -BootSetup }
else { & "$PSScriptRoot\Start-Lab.ps1" -BootSetup }
'Configuring - inspect logs before rerunning' | Set-Content (Join-Path $LabRoot 'build-stage.txt')
$dcCredential=Import-Clixml (Join-Path $LabRoot 'credentials\dc.xml')
$storedClientCredential=Import-Clixml (Join-Path $LabRoot 'credentials\client.xml')
$clientCredential=[pscredential]::new('CLIENT01\LabAdmin',$storedClientCredential.Password)
$dsrm=Import-Clixml (Join-Path $LabRoot 'credentials\dsrm.xml')
if ($Stage -ne 'ConfigureClient') {
$session=Open-LabSession DC01 $dcCredential
try {
    Remove-LabSetupDrive DC01
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
    $backupPath=Join-Path $LabRoot 'DC01\DC01-backup.vhdx'
    if (-not (Test-Path $backupPath)) { & "$PSScriptRoot\Add-LabBackupDisk.ps1" -LabRoot $LabRoot }
    Invoke-Command -Session $session {
        $ErrorActionPreference='Stop'
        & C:\LabRepo\scripts\server\Initialize-LabDomain.ps1 -Confirm:$false
        & C:\LabRepo\scripts\server\Initialize-LabShares.ps1
        & C:\LabRepo\scripts\server\Initialize-LabPrinter.ps1
        & C:\LabRepo\scripts\server\Set-LabGroupPolicy.ps1
        & C:\LabRepo\scripts\server\Initialize-LabBackupDisk.ps1 -Confirm:$false
    }
} finally { Remove-PSSession $session }
'DCConfigured' | Set-Content (Join-Path $LabRoot 'build-stage.txt')
if ($Stage -eq 'ConfigureDC') { return }
} else {
    $domainCredential=[pscredential]::new('CORP\Administrator',$dcCredential.Password)
}
$session=Open-LabSession CLIENT01 $clientCredential
$clientBootBefore=[datetime]::MinValue
try {
    Remove-LabSetupDrive CLIENT01
    Copy-LabSource $session
    if ($ResumeClient) {
        Invoke-Command -Session $session {
            $computer=Get-CimInstance Win32_ComputerSystem
            if ($computer.Name -ne 'CLIENT01' -or -not $computer.PartOfDomain -or $computer.Domain -ne 'corp.lab') { throw 'Resume requires verified CLIENT01 membership in corp.lab.' }
            if (-not (Test-ComputerSecureChannel)) { throw 'Repair the client secure channel before resuming configuration.' }
        }
    } else {
        $clientBootBefore=Invoke-Command -Session $session { (Get-CimInstance Win32_OperatingSystem).LastBootUpTime }
        Invoke-Command -Session $session {
            & C:\LabRepo\scripts\client\Join-LabDomain.ps1 -DomainCredential $using:domainCredential -Confirm:$false
        }
    }
} finally { Remove-PSSession $session }
if (-not $ResumeClient) { Start-Sleep -Seconds 60 }
$session=Open-LabSession CLIENT01 $clientCredential -BootAfter $clientBootBefore
try {
    Invoke-Command -Session $session {
        & C:\LabRepo\scripts\client\Install-LabRSAT.ps1
        # Pre-stage the inbox driver as an administrator; retain Point and Print protections.
        & C:\LabRepo\scripts\common\Install-LabPrinterDriver.ps1
        gpupdate.exe /force
        Get-CimInstance Win32_ComputerSystem | Select-Object Name,Domain,PartOfDomain
    }
} finally { Remove-PSSession $session }
'DomainConfigured - tickets, printer, backup, recovery and user evidence still pending' | Set-Content (Join-Path $LabRoot 'build-stage.txt')
