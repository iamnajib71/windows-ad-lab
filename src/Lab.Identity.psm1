Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Server = 'DC01.corp.lab'
$script:DomainDN = 'DC=corp,DC=lab'
$script:Departments = @('Finance', 'HR', 'IT')

function Assert-LabDomain {
    $domain = Get-ADDomain -Server $script:Server
    if ($domain.DNSRoot -ne 'corp.lab') { throw 'Refusing to operate outside corp.lab.' }
}

function Get-LabOnboardingPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$CsvPath)
    $rows = @(Import-Csv -LiteralPath $CsvPath)
    if ($rows.Count -eq 0) { throw 'CSV is empty.' }
    $seen = @{}
    foreach ($row in $rows) {
        foreach ($column in @('SamAccountName','GivenName','Surname','Department','Title')) {
            if ($column -notin $row.PSObject.Properties.Name -or [string]::IsNullOrWhiteSpace($row.$column)) {
                throw "Missing value or column: $column"
            }
        }
        if ($row.SamAccountName -notmatch '^[a-z][a-z0-9.]{0,19}$') { throw 'Invalid lab account name.' }
        if ($row.Department -notin $script:Departments) { throw 'Unknown department.' }
        if ($seen.ContainsKey($row.SamAccountName)) { throw 'Duplicate account in CSV.' }
        $seen[$row.SamAccountName] = $true
    }
    foreach ($row in $rows) {
        [pscustomobject]@{
            SamAccountName = $row.SamAccountName
            GivenName = $row.GivenName
            Surname = $row.Surname
            DisplayName = "$($row.GivenName) $($row.Surname)"
            Department = $row.Department
            Title = $row.Title
            Group = "GG_$($row.Department)"
            Path = "OU=$($row.Department),OU=Staff,$script:DomainDN"
            HomeDirectory = "\\DC01\Homes\$($row.SamAccountName)"
            EmailAddress = "$($row.SamAccountName)@corp.example.invalid"
        }
    }
}

function Get-LabStaffUser {
    param([Parameter(Mandatory)][string]$Identity)
    $user = Get-ADUser -Identity $Identity -Server $script:Server -Properties MemberOf
    if ($user.DistinguishedName -notlike "*,OU=Staff,$script:DomainDN" -and
        $user.DistinguishedName -notlike "*,OU=Disabled,$script:DomainDN") {
        throw 'Only Staff and Disabled OU users may be managed by these helpers.'
    }
    $user
}

function Invoke-LabOnboarding {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory)][string]$CsvPath,
        [Parameter(Mandatory)][securestring]$InitialPassword,
        [string]$HomeRoot = 'C:\LabData\Homes'
    )
    $plan = @(Get-LabOnboardingPlan -CsvPath $CsvPath)
    Assert-LabDomain
    # Resolve every dependency before making the first change.
    foreach ($item in $plan) {
        $null = Get-ADGroup -Identity $item.Group -Server $script:Server
        $null = Get-ADOrganizationalUnit -Identity $item.Path -Server $script:Server
        if (Get-ADUser -Filter "SamAccountName -eq '$($item.SamAccountName)'" -Server $script:Server) {
            throw "Account already exists: $($item.SamAccountName). No changes made."
        }
        if (Test-Path -LiteralPath (Join-Path $HomeRoot $item.SamAccountName)) { throw 'Home folder already exists; review ownership first.' }
    }
    foreach ($item in $plan) {
        if ($PSCmdlet.ShouldProcess($item.SamAccountName, 'Create account, private home folder and department membership')) {
            $created = $false
            try {
                $newUser = @{
                    Name = $item.DisplayName; SamAccountName = $item.SamAccountName
                    GivenName = $item.GivenName; Surname = $item.Surname
                    DisplayName = $item.DisplayName; Department = $item.Department; Title = $item.Title
                    UserPrincipalName = "$($item.SamAccountName)@corp.lab"
                    EmailAddress = $item.EmailAddress; Path = $item.Path
                    HomeDirectory = $item.HomeDirectory; HomeDrive = 'H:'
                    AccountPassword = $InitialPassword; Enabled = $false
                    ChangePasswordAtLogon = $true; Server = $script:Server
                }
                New-ADUser @newUser
                $created = $true
                $user = Get-ADUser -Identity $item.SamAccountName -Server $script:Server
                $folder = Join-Path $HomeRoot $item.SamAccountName
                $null = New-Item -ItemType Directory -Path $folder
                $acl = [System.Security.AccessControl.DirectorySecurity]::new()
                $acl.SetAccessRuleProtection($true, $false)
                foreach ($entry in @(@('S-1-5-18','FullControl'), @('S-1-5-32-544','FullControl'), @($user.SID.Value,'Modify'))) {
                    $sid = [System.Security.Principal.SecurityIdentifier]::new($entry[0])
                    $rule = [System.Security.AccessControl.FileSystemAccessRule]::new($sid, $entry[1], 'ContainerInherit,ObjectInherit', 'None', 'Allow')
                    $acl.AddAccessRule($rule)
                }
                Set-Acl -LiteralPath $folder -AclObject $acl
                Add-ADGroupMember -Identity $item.Group -Members $item.SamAccountName -Server $script:Server
                Enable-ADAccount -Identity $item.SamAccountName -Server $script:Server
                [pscustomobject]@{ Account=$item.SamAccountName; Result='Created'; Department=$item.Department }
            } catch {
                if ($created) { Disable-ADAccount -Identity $item.SamAccountName -Server $script:Server }
                throw # Partial account stays disabled for investigation; do not silently delete data.
            }
        }
    }
}

function Reset-LabPassword {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$Identity, [Parameter(Mandatory)][securestring]$NewPassword)
    Assert-LabDomain
    $user = Get-LabStaffUser $Identity
    if ($PSCmdlet.ShouldProcess($Identity, 'Reset password and require change at next sign-in')) {
        Set-ADAccountPassword -Identity $user -Reset -NewPassword $NewPassword -Server $script:Server
        Set-ADUser -Identity $user -ChangePasswordAtLogon $true -Server $script:Server
    }
}

function Unlock-LabUser {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$Identity)
    Assert-LabDomain
    $user = Get-LabStaffUser $Identity
    if ($PSCmdlet.ShouldProcess($Identity, 'Unlock domain account')) {
        Unlock-ADAccount -Identity $user -Server $script:Server
    }
}

function Disable-LabUser {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param([Parameter(Mandatory)][string]$Identity)
    Assert-LabDomain
    $user = Get-LabStaffUser $Identity
    if ($PSCmdlet.ShouldProcess($Identity, 'Disable, strip direct groups, and move to Disabled OU')) {
        Disable-ADAccount -Identity $user -Server $script:Server
        foreach ($group in $user.MemberOf) {
            Remove-ADGroupMember -Identity $group -Members $user -Confirm:$false -Server $script:Server
        }
        Move-ADObject -Identity $user.DistinguishedName -TargetPath "OU=Disabled,$script:DomainDN" -Server $script:Server
    }
}

function Update-LabGroupMembership {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$CsvPath)
    Assert-LabDomain
    $rows = @(Import-Csv -LiteralPath $CsvPath)
    if ($rows.Count -eq 0) { throw 'CSV is empty.' }
    $validated = foreach ($row in $rows) {
        if ($row.Group -notin @('GG_Finance','GG_HR','GG_IT') -or $row.Action -notin @('Add','Remove')) { throw 'Invalid group or action.' }
        $user = Get-LabStaffUser $row.SamAccountName
        $null = Get-ADGroup -Identity $row.Group -Server $script:Server
        [pscustomobject]@{ User=$user; Group=$row.Group; Action=$row.Action }
    }
    foreach ($row in $validated) {
        if ($PSCmdlet.ShouldProcess($row.User.SamAccountName, "$($row.Action) membership of $($row.Group)")) {
            if ($row.Action -eq 'Add') { Add-ADGroupMember -Identity $row.Group -Members $row.User -Server $script:Server }
            else { Remove-ADGroupMember -Identity $row.Group -Members $row.User -Confirm:$false -Server $script:Server }
        }
    }
}

function Get-LabStaleAccount {
    [CmdletBinding(SupportsShouldProcess)]
    param([ValidateRange(1,3650)][int]$InactiveDays=90, [string]$OutputPath)
    Assert-LabDomain
    $cutoff = (Get-Date).AddDays(-$InactiveDays)
    $users = @(Get-ADUser -Filter * -SearchBase "OU=Staff,$script:DomainDN" -Server $script:Server -Properties LastLogonDate,whenCreated,Enabled |
        Where-Object { ($_.LastLogonDate -and $_.LastLogonDate -lt $cutoff) -or (-not $_.LastLogonDate -and $_.whenCreated -lt $cutoff) } |
        Select-Object SamAccountName,Enabled,LastLogonDate,whenCreated)
    if ($OutputPath -and $PSCmdlet.ShouldProcess($OutputPath, 'Write approximate stale-account CSV report')) {
        $users | Export-Csv -LiteralPath $OutputPath -NoTypeInformation
    }
    $users
}

Export-ModuleMember -Function Get-LabOnboardingPlan,Invoke-LabOnboarding,Reset-LabPassword,Unlock-LabUser,Disable-LabUser,Update-LabGroupMembership,Get-LabStaleAccount
