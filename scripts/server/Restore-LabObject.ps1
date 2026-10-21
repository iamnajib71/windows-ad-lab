[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param([Parameter(Mandatory)][guid]$ObjectGuid)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory
if ((Get-ADDomain -Server DC01.corp.lab).DNSRoot -ne 'corp.lab') { throw 'Wrong domain.' }
$object=Get-ADObject -Identity $ObjectGuid -IncludeDeletedObjects -Properties lastKnownParent,isDeleted -Server DC01.corp.lab
if (-not $object.isDeleted -or $object.lastKnownParent -notlike '*,OU=Staff,DC=corp,DC=lab') { throw 'Only a deleted lab Staff object may be restored.' }
if ($PSCmdlet.ShouldProcess($ObjectGuid,'Restore deleted fictional Staff object to original OU')) {
    Restore-ADObject -Identity $object -Server DC01.corp.lab
    Get-ADObject -Identity $ObjectGuid -Server DC01.corp.lab
}
