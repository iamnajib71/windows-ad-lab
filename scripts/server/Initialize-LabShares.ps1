#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param([string]$DataRoot='C:\LabData')
$ErrorActionPreference='Stop'
if ($env:COMPUTERNAME -ne 'DC01') { throw 'Run inside DC01 only. Guest C: is a virtual disk on the lab data volume.' }
if ($PSCmdlet.ShouldProcess($DataRoot,'Create department shares with protected NTFS ACLs and access-based enumeration')) {
    foreach ($department in @('Finance','HR','IT','Homes')) {
        $path=Join-Path $DataRoot $department
        $null=New-Item -ItemType Directory -Path $path -Force
        $acl=[System.Security.AccessControl.DirectorySecurity]::new()
        $acl.SetAccessRuleProtection($true,$false)
        foreach ($sidValue in @('S-1-5-18','S-1-5-32-544')) {
            $sid=[System.Security.Principal.SecurityIdentifier]::new($sidValue)
            $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
        }
        $principal=if ($department -eq 'Homes') { 'CORP\Domain Users' } else { "CORP\DL_${department}_Modify" }
        $rights=if ($department -eq 'Homes') { 'ReadAndExecute' } else { 'Modify' }
        $inherit=if ($department -eq 'Homes') { 'None' } else { 'ContainerInherit,ObjectInherit' }
        $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($principal,$rights,$inherit,'None','Allow'))
        Set-Acl -LiteralPath $path -AclObject $acl
        $share=Get-SmbShare -Name $department -ErrorAction SilentlyContinue
        if ($share -and $share.Path -ne $path) { throw "Share $department already points elsewhere." }
        if (-not $share) {
            $null=New-SmbShare -Name $department -Path $path -FullAccess 'CORP\Domain Admins' -ChangeAccess $principal -FolderEnumerationMode AccessBased -CachingMode None
        } else {
            $grants=@(Get-SmbShareAccess -Name $department)
            $unexpected=@($grants | Where-Object {
                $_.AccessControlType -ne 'Allow' -or
                ($_.AccountName -ne 'CORP\Domain Admins' -and $_.AccountName -ne $principal) -or
                ($_.AccountName -eq $principal -and $_.AccessRight -ne 'Change')
            })
            if ($unexpected.Count -or $grants.Count -ne 2) { throw "Share $department has unexpected grants; review before reusing it." }
            Set-SmbShare -Name $department -FolderEnumerationMode AccessBased -CachingMode None -Force
        }
    }
}
