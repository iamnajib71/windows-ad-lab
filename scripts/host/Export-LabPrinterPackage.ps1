[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$LabRoot='H:\My Projects - IT\windows-ad-lab\.lab',
    [string]$ArchiveTool=(Join-Path $PSScriptRoot '..\..\.tools\7zip\portable\7z.exe')
)
$ErrorActionPreference='Stop'
$LabRoot=[IO.Path]::GetFullPath($LabRoot)
if ([IO.Path]::GetPathRoot($LabRoot) -eq 'C:\') { throw 'Extract lab media only on the data drive.' }
$iso=Join-Path $LabRoot 'iso\server-2022-eval.iso'
$destination=Join-Path $LabRoot 'drivers\GenericTextOnly'
if (Test-Path -LiteralPath (Join-Path $destination 'prnge001.inf')) { return $destination }
if (-not (Test-Path -LiteralPath $ArchiveTool) -or -not (Test-Path -LiteralPath $iso)) { throw 'Provide the official 7-Zip archive executable and completed Server evaluation ISO first.' }
if (-not $PSCmdlet.ShouldProcess($destination,'Extract signed Generic/Text printer package from evaluation image 2 as ordinary files')) { return }
$media=Join-Path $LabRoot 'drivers\media'
$extracted=Join-Path $LabRoot 'drivers\extracted'
$null=New-Item -ItemType Directory -Path $media,$extracted -Force
$wim=Join-Path $media 'install.wim'
if (-not (Test-Path -LiteralPath $wim)) {
    & $ArchiveTool e $iso 'sources\install.wim' "-o$media" -y -bb0 -bsp0
    if ($LASTEXITCODE -ne 0) { throw 'Evaluation image extraction failed.' }
}
$listing=@(& $ArchiveTool l $wim '2\Windows\System32\DriverStore\FileRepository\prnge001.inf_amd64_*\prnge001.inf' -slt)
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the completed evaluation image archive.' }
$package=@($listing | ForEach-Object {
    $entry=[regex]::Match($_,'^Path = (2\\Windows\\System32\\DriverStore\\FileRepository\\prnge001\.inf_amd64_[0-9a-f]+)\\prnge001\.inf$')
    if ($entry.Success) { $entry.Groups[1].Value }
} | Select-Object -Unique)
if ($package.Count -ne 1) { throw 'Expected one original x64 Generic/Text driver package in evaluation Desktop Experience image 2.' }
& $ArchiveTool x $wim ($package[0]+'\*') "-o$extracted" -y -bb0 -bsp0
if ($LASTEXITCODE -ne 0) { throw 'Printer package extraction failed.' }
$source=Join-Path $extracted $package[0]
if (-not (Test-Path -LiteralPath (Join-Path $source 'prnge001.cat'))) { throw 'The original signed catalog is missing.' }
Copy-Item -LiteralPath $source -Destination $destination -Recurse
Get-ChildItem -LiteralPath $destination -File -Recurse | Get-FileHash -Algorithm SHA256 | Export-Csv (Join-Path $LabRoot 'drivers\package-sha256.csv') -NoTypeInformation
$destination
