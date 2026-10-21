function Get-LabImageSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('DC01','CLIENT01')][string]$VMName,
        [Parameter(Mandatory)][object[]]$Images
    )
    $candidates=@(if ($VMName -eq 'DC01') {
        $Images | Where-Object ImageName -match '^Windows Server 2022 Standard Evaluation\s*$|^Windows Server 2022 SERVERSTANDARDCORE$'
    } else {
        $Images | Where-Object ImageName -match '^Windows 11 Enterprise Evaluation\s*$'
    })
    if ($candidates.Count -ne 1) { throw 'Expected exactly one matching evaluation image; inspect WIM metadata before partitioning.' }
    $candidates[0]
}
Export-ModuleMember -Function Get-LabImageSelection
