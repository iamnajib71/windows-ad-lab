[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Baseline','Ticket01Before','Ticket01After','Ticket02Before','Ticket02After','Ticket03Before','Ticket03After','Ticket05Before','Ticket05After','FinalChecks','Demo')][string]$Step='Baseline',
    [string]$OutputDirectory=(Join-Path $env:USERPROFILE 'Documents\LabEvidence')
)
$ErrorActionPreference='Stop'
if ($env:COMPUTERNAME -ne 'CLIENT01' -or [Security.Principal.WindowsIdentity]::GetCurrent().Name -ne 'CORP\alex.morgan') {
    throw 'Run in the actual CLIENT01 / CORP\alex.morgan interactive session.'
}
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
if (-not $OutputDirectory.StartsWith(([IO.Path]::GetFullPath($env:USERPROFILE)+'\'),[StringComparison]::OrdinalIgnoreCase)) {
    throw 'Save staff evidence inside the fictional user profile.'
}
if (-not $PSCmdlet.ShouldProcess("CLIENT01 / $Step",'Refresh user policy and capture actual staff-session results')) { return }
$null=New-Item -ItemType Directory -Path $OutputDirectory -Force
Start-Transcript -Path (Join-Path $OutputDirectory "$Step-transcript.txt") -Force
try {
    Write-Output "Actual staff session: $Step / $((Get-Date).ToString('o'))"
    & whoami.exe
    if ($Step -eq 'Ticket02Before') {
        $mapping=Get-SmbMapping -LocalPath 'F:' -ErrorAction SilentlyContinue
        if ($mapping -and $mapping.RemotePath -notin @('\\DC01\Finance','\\DC01\HR')) { throw 'Unexpected F: target; leave it unchanged.' }
        if ($mapping) { Remove-SmbMapping -LocalPath 'F:' -Force }
    }
    $gpExit=$null
    if ($Step -notin @('Ticket01Before','Ticket01After')) {
        Write-Output 'PS> gpupdate /target:user /force'
        & gpupdate.exe /target:user /force
        $gpExit=$LASTEXITCODE
        Write-Output 'PS> gpresult /scope user /r'
        & gpresult.exe /scope user /r | Tee-Object -FilePath (Join-Path $OutputDirectory "$Step-gpresult.txt")
        & gpresult.exe /scope user /h (Join-Path $OutputDirectory "$Step-gpresult.html") /f
    } else {
        $serverResult="C:\LabEvidence\$Step-server.txt"
        if (Test-Path -LiteralPath $serverResult) {
            Write-Output 'Actual DC01 account/authentication results collected separately:'
            Get-Content -LiteralPath $serverResult
        }
    }
    & whoami.exe /groups | Out-File (Join-Path $OutputDirectory "$Step-groups.txt")
    $restriction=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name NoControlPanel -ErrorAction SilentlyContinue
    $noControlPanel=if ($restriction) { $restriction.NoControlPanel } else { $null }
    $financeError=$null
    $financeAccess=$true
    try { $null=Get-ChildItem '\\DC01\Finance' -ErrorAction Stop }
    catch { $financeAccess=$false; $financeError=$_.Exception.Message }
    $writtenFile=$null
    $readBack=$null
    if ($Step -in @('Ticket02After','Ticket05After')) {
        $writtenFile="\\DC01\Finance\lab-$($Step.ToLowerInvariant())-alex.txt"
        "Fictional lab access verification: $((Get-Date).ToString('o'))" | Set-Content -LiteralPath $writtenFile
        $readBack=[IO.File]::ReadAllText($writtenFile).TrimEnd()
    }
    $otherHomeAccess=$true
    $otherHomeError=$null
    try { $null=Get-ChildItem -LiteralPath '\\DC01\Homes\jamie.chen' -ErrorAction Stop }
    catch { $otherHomeAccess=$false; $otherHomeError=$_.Exception.Message }
    $summary=[ordered]@{
        CapturedAt=(Get-Date).ToString('o');Computer=$env:COMPUTERNAME
        User=[Security.Principal.WindowsIdentity]::GetCurrent().Name;Step=$Step
        GPUpdateExitCode=$gpExit;NoControlPanel=$noControlPanel
        DriveMappings=@(Get-SmbMapping | Select-Object LocalPath,RemotePath,Status)
        Printers=@(Get-Printer | Select-Object Name,DriverName)
        FinanceAccess=$financeAccess;FinanceError=$financeError
        OwnHomeAccess=(Test-Path '\\DC01\Homes\alex.morgan' -ErrorAction SilentlyContinue)
        HRAccess=(Test-Path '\\DC01\HR' -ErrorAction SilentlyContinue)
        OtherHomeAccess=$otherHomeAccess;OtherHomeError=$otherHomeError
        WrittenFile=$writtenFile;ReadBack=$readBack
    }
    $summary | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $OutputDirectory "$Step-state.json")
    Write-Output 'PS> Get-SmbMapping'
    Get-SmbMapping | Format-Table LocalPath,RemotePath,Status -AutoSize
    Write-Output 'Observed access and desktop policy:'
    [pscustomobject]$summary | Format-List Computer,User,Step,GPUpdateExitCode,NoControlPanel,FinanceAccess,FinanceError,OwnHomeAccess,HRAccess,OtherHomeAccess,WrittenFile,ReadBack
    if ($Step -eq 'FinalChecks') {
        $module='C:\LabModules\5.7.1\Pester.psd1'
        if (Test-Path -LiteralPath $module) { Import-Module $module }
        else { Import-Module Pester -RequiredVersion 5.7.1 }
        $config=New-PesterConfiguration
        $config.Run.Path='C:\LabRepo\acceptance\Client.Acceptance.Tests.ps1'
        $config.Run.PassThru=$true
        $config.Output.Verbosity='Detailed'
        $result=Invoke-Pester -Configuration $config
        [ordered]@{CapturedAt=(Get-Date).ToString('o');Computer=$env:COMPUTERNAME;User=[Security.Principal.WindowsIdentity]::GetCurrent().Name;Passed=$result.PassedCount;Failed=$result.FailedCount;NotRun=$result.NotRunCount;Failures=@($result.Failed | ForEach-Object { $_.Name })} | ConvertTo-Json | Set-Content (Join-Path $OutputDirectory 'client-staff-acceptance.json')
        if ($result.FailedCount) { throw 'Real staff acceptance has failures; inspect evidence before claiming completion.' }
    }
} finally { Stop-Transcript }
if ($Step -in @('Ticket03Before','Ticket03After')) { Start-Process control.exe }
