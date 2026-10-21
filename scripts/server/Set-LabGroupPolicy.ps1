#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param([ValidatePattern('^\\\\[A-Za-z0-9.-]+\\[A-Za-z0-9_-]+$')][string]$PrinterPath='\\DC01\LAB-Printer')
$ErrorActionPreference='Stop'
Import-Module GroupPolicy
Import-Module ActiveDirectory
if ($env:COMPUTERNAME -ne 'DC01' -or (Get-ADDomain).DNSRoot -ne 'corp.lab') { throw 'Run on DC01 / corp.lab only.' }
if (-not $PSCmdlet.ShouldProcess('corp.lab','Create and link LAB policies, including drive/printer preferences')) { return }
$dn='DC=corp,DC=lab'
function Get-OrCreatePolicy {
    param([string]$Name,[string]$Target)
    $gpo=Get-GPO -Name $Name -ErrorAction SilentlyContinue
    if (-not $gpo) { $gpo=New-GPO -Name $Name }
    if (-not ((Get-GPInheritance -Target $Target).GpoLinks | Where-Object DisplayName -eq $Name)) {
        $null=New-GPLink -Guid $gpo.Id -Target $Target -LinkEnabled Yes
    }
    $gpo
}
function Write-Preference {
    param($Gpo,[string]$Kind,[xml]$Xml,[string]$Extension)
    $guid=$Gpo.Id.ToString('B').ToUpperInvariant()
    $path="\\DC01\SYSVOL\corp.lab\Policies\$guid\User\Preferences\$Kind"
    $null=New-Item -ItemType Directory -Path $path -Force
    $Xml.Save((Join-Path $path "$Kind.xml"))
    # The supported registry cmdlet increments both GPT and GPC user versions.
    $null=Set-GPRegistryValue -Guid $Gpo.Id -Key 'HKCU\Software\Policies\CorpLab' -ValueName PolicyRevision -Type DWord -Value ([int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
    $identity="CN=$guid,CN=Policies,CN=System,$dn"
    $object=Get-ADObject -Identity $identity -Properties gPCUserExtensionNames
    $blocks=@([regex]::Matches([string]$object.gPCUserExtensionNames,'\[[^\]]+\]') | ForEach-Object Value)
    if ($Extension -notin $blocks) { $blocks += $Extension }
    Set-ADObject -Identity $identity -Replace @{gPCUserExtensionNames=(($blocks | Sort-Object) -join '')}
}
$baseline=Get-OrCreatePolicy 'LAB-Security-Baseline' $dn
foreach ($setting in @(
    @('HKLM\Software\Policies\Microsoft\Windows NT\DNSClient','EnableMulticast',0),
    @('HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters','RequireSecuritySignature',1),
    @('HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters','RequireSecuritySignature',1)
)) {
    $null=Set-GPRegistryValue -Guid $baseline.Id -Key $setting[0] -ValueName $setting[1] -Type DWord -Value $setting[2]
}
$updates=Get-OrCreatePolicy 'LAB-Windows-Update' "OU=Computers,OU=Lab,$dn"
foreach ($setting in @(@('NoAutoUpdate',0),@('AUOptions',4),@('ScheduledInstallDay',0),@('ScheduledInstallTime',3),@('NoAutoRebootWithLoggedOnUsers',1))) {
    $null=Set-GPRegistryValue -Guid $updates.Id -Key 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' -ValueName $setting[0] -Type DWord -Value $setting[1]
}
$desktop=Get-OrCreatePolicy 'LAB-Desktop-Restrictions' "OU=Staff,$dn"
$null=Set-GPRegistryValue -Guid $desktop.Id -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -ValueName NoControlPanel -Type DWord -Value 1
# Account policy is configured at the domain with Set-ADDefaultDomainPasswordPolicy.
# This GPO's security template makes that policy visible in GPMC too.
$password=Get-OrCreatePolicy 'LAB-Domain-Account-Policy' $dn
$guid=$password.Id.ToString('B').ToUpperInvariant()
$securityPath="\\DC01\SYSVOL\corp.lab\Policies\$guid\Machine\Microsoft\Windows NT\SecEdit"
$null=New-Item -ItemType Directory -Path $securityPath -Force
@'
[Unicode]
Unicode=yes
[Version]
signature="$CHICAGO$"
Revision=1
[System Access]
MinimumPasswordAge=1
MaximumPasswordAge=90
MinimumPasswordLength=14
PasswordComplexity=1
PasswordHistorySize=24
LockoutBadCount=5
ResetLockoutCount=15
LockoutDuration=15
ClearTextPassword=0
'@ | Set-Content -LiteralPath (Join-Path $securityPath 'GptTmpl.inf') -Encoding Unicode
$null=Set-GPRegistryValue -Guid $password.Id -Key 'HKLM\Software\Policies\CorpLab' -ValueName PolicyRevision -Type DWord -Value ([int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
$policyDN="CN=$guid,CN=Policies,CN=System,$dn"
$object=Get-ADObject $policyDN -Properties gPCMachineExtensionNames
$blocks=@([regex]::Matches([string]$object.gPCMachineExtensionNames,'\[[^\]]+\]') | ForEach-Object Value)
$blocks+='[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}]'
Set-ADObject $policyDN -Replace @{gPCMachineExtensionNames=(($blocks | Sort-Object -Unique) -join '')}
foreach ($department in @('Finance','HR','IT')) {
    $gpo=Get-OrCreatePolicy "LAB-Drive-$department" "OU=Staff,$dn"
    $sid=(Get-ADGroup "GG_$department").SID.Value
    $uid=[guid]::NewGuid().ToString('B')
    $letter=@{Finance='F';HR='R';IT='I'}[$department]
    $xml=@"
<Drives clsid="{8FDDCC1A-0C3C-43cd-A6B4-71A6DF20DA8C}">
 <Drive clsid="{935D1B74-9CB8-4e3c-9914-7DD559B7A417}" name="${letter}:" status="${letter}:" image="2" uid="$uid" userContext="1" removePolicy="1">
  <Properties action="U" thisDrive="NOCHANGE" allDrives="NOCHANGE" userName="" path="\\DC01\$department" label="$department" persistent="0" useLetter="1" letter="$letter"/>
  <Filters><FilterGroup bool="AND" not="0" name="CORP\GG_$department" sid="$sid" userContext="1" primaryGroup="0" localGroup="0"/></Filters>
 </Drive>
</Drives>
"@
    Write-Preference $gpo Drives $xml '[{5794DAFD-BE60-433f-88A2-1A31939AC01F}{2EA1A81B-48E5-45E9-8BB7-A6E3AC170006}]'
}
$printer=Get-OrCreatePolicy 'LAB-Printer-Deployment' "OU=Staff,$dn"
$uid=[guid]::NewGuid().ToString('B')
$xml=@"
<Printers clsid="{1F577D12-3D1B-471e-A1B7-060317597B9C}">
 <SharedPrinter clsid="{9A5E9697-9095-436d-A0EE-4D128FDFBCE5}" name="LAB-Printer" status="LAB-Printer" image="2" uid="$uid" userContext="1" removePolicy="1">
  <Properties action="U" path="$PrinterPath" location="Virtual lab" default="0" skipLocal="0" deleteAll="0" persistent="0" deleteMaps="0" port=""/>
 </SharedPrinter>
</Printers>
"@
Write-Preference $printer Printers $xml '[{BC75B1ED-5833-4858-9BB8-CBF0B166DF9D}{A8C42CEA-CDB8-4388-97F4-5831F933DA84}]'
Write-Output 'Policies configured. Verify GPMC, gpresult, registry and actual drive/printer behaviour before claiming success.'
