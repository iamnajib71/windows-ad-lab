#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('DC01','CLIENT01')][string]$VMName='DC01',
    [string]$OutputPath='H:\My Projects - IT\windows-ad-lab\.lab\console\DC01.png'
)
$ErrorActionPreference='Stop'
$OutputPath=[IO.Path]::GetFullPath($OutputPath)
if ([IO.Path]::GetPathRoot($OutputPath) -eq 'C:\') { throw 'Save console captures on the lab data drive.' }
$vm=Get-VM -Name $VMName
if ($vm.State -ne 'Running') { throw 'The requested lab VM is not running.' }
if (-not $PSCmdlet.ShouldProcess($OutputPath,"Capture actual $VMName framebuffer through read-only Hyper-V API")) { return }
$system=Get-CimInstance -Namespace root/virtualization/v2 -ClassName Msvm_ComputerSystem -Filter "Name='$($vm.Id)'"
$settings=@(Get-CimAssociatedInstance -InputObject $system -Association Msvm_SettingsDefineState -ResultClassName Msvm_VirtualSystemSettingData)
if ($settings.Count -ne 1) { throw 'Expected one current VM setting record.' }
$service=Get-CimInstance -Namespace root/virtualization/v2 -ClassName Msvm_VirtualSystemManagementService
$width=1024; $height=768
$capture=Invoke-CimMethod -InputObject $service -MethodName GetVirtualSystemThumbnailImage -Arguments @{TargetSystem=$settings[0];WidthPixels=[uint16]$width;HeightPixels=[uint16]$height}
if ($capture.ReturnValue -ne 0) { throw "Hyper-V framebuffer capture failed: $($capture.ReturnValue)" }
$bytes=[byte[]]$capture.ImageData
$offset=0
if ($bytes.Length -eq $width*$height*2+4 -and ($bytes[0]*16777216+$bytes[1]*65536+$bytes[2]*256+$bytes[3]) -eq $bytes.Length) {
    $offset=4 # This host prefixes the RGB565 payload with its big-endian packet length.
} elseif ($bytes.Length -ne $width*$height*2) {
    throw "Unexpected RGB565 framebuffer length: $($bytes.Length); expected $($width*$height*2). Header: $($bytes[0..3] -join ',')."
}
Add-Type -AssemblyName System.Drawing
$bitmap=[Drawing.Bitmap]::new($width,$height,[Drawing.Imaging.PixelFormat]::Format16bppRgb565)
try {
    $rectangle=[Drawing.Rectangle]::new(0,0,$width,$height)
    $data=$bitmap.LockBits($rectangle,[Drawing.Imaging.ImageLockMode]::WriteOnly,[Drawing.Imaging.PixelFormat]::Format16bppRgb565)
    try { [Runtime.InteropServices.Marshal]::Copy($bytes,$offset,$data.Scan0,$width*$height*2) }
    finally { $bitmap.UnlockBits($data) }
    $null=New-Item -ItemType Directory -Path (Split-Path $OutputPath -Parent) -Force
    $bitmap.Save($OutputPath,[Drawing.Imaging.ImageFormat]::Png)
} finally { $bitmap.Dispose() }
[pscustomobject]@{CapturedAt=(Get-Date).ToString('o');VM=$VMName;Source='Hyper-V framebuffer RGB565';Path=$OutputPath}
