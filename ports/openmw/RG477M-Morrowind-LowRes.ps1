# RG477M-Morrowind-LowRes.ps1: shrinks the textures of an installed "Morrowind Android" mod
# list (made by RG477M-Morrowind.ps1) to handheld size, then zips it again.
#
# Every .dds texture bigger than -MaxSize (default 1024) on its longest side is halved until it
# fits, in its own format and with fresh mipmaps, using Microsoft's texconv. Mods that only come
# in HD then load like their low-resolution versions, the folder gets much smaller and OpenMW
# 477M needs no texture shrinking. Textures inside .bsa archives are left as they are.
#
# Run it in PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\RG477M-Morrowind-LowRes.ps1
# It can be run again: textures already small enough are skipped.
# To get the full-size textures back, run RG477M-Morrowind.ps1 again (it reuses its downloads).

param(
    [string]$Work = "C:\Morrowind477M",
    [int]$MaxSize = 1024,
    [switch]$NoZip
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Out = Join-Path $Work "Morrowind Android"
$Momw = Join-Path $Out "momw"
$Tools = Join-Path $Work "tools"
$Temp = Join-Path $Work "lowres-temp"

function Step($text) { Write-Host ""; Write-Host "== $text" -ForegroundColor Cyan }
function Fail($text) { Write-Host $text -ForegroundColor Red; exit 1 }

if (-not (Test-Path (Join-Path $Momw "openmw.cfg"))) {
    Fail "No mod list in $Out. Run RG477M-Morrowind.ps1 first."
}

Step "Getting texconv"
New-Item -ItemType Directory -Force $Tools | Out-Null
$texconv = Join-Path $Tools "texconv.exe"
if (-not (Test-Path $texconv)) {
    Invoke-WebRequest "https://github.com/Microsoft/DirectXTex/releases/latest/download/texconv.exe" -OutFile $texconv
}

# ---------------------------------------------------------------------------- finding textures

Step "Finding textures over $MaxSize pixels"
$formats = @{ "DXT1" = "BC1_UNORM"; "DXT3" = "BC2_UNORM"; "DXT5" = "BC3_UNORM" }
$folders = @("momw\extra", "OpenMWMods") | ForEach-Object { Join-Path $Out $_ } | Where-Object { Test-Path $_ }
$groups = @{}
$found = 0; $skipped = 0; $before = 0

foreach ($file in Get-ChildItem $folders -Recurse -File -Filter *.dds) {
    $header = New-Object byte[] 128
    $stream = [IO.File]::OpenRead($file.FullName)
    try { $read = $stream.Read($header, 0, 128) } finally { $stream.Close() }
    if ($read -lt 128 -or [Text.Encoding]::ASCII.GetString($header, 0, 4) -ne "DDS ") { $skipped++; continue }
    $height = [BitConverter]::ToUInt32($header, 12)
    $width = [BitConverter]::ToUInt32($header, 16)
    $caps2 = [BitConverter]::ToUInt32($header, 112)
    $fourcc = [Text.Encoding]::ASCII.GetString($header, 84, 4)
    if ([Math]::Max($width, $height) -le $MaxSize) { continue }
    # cube maps and volume textures are rare in mods; leave them be
    if (($caps2 -band 0x200200) -ne 0) { $skipped++; continue }
    if ($fourcc -eq "DX10") { $skipped++; continue }

    $w = $width; $h = $height
    while ([Math]::Max($w, $h) -gt $MaxSize) { $w = [Math]::Max(4, [int]($w / 2)); $h = [Math]::Max(4, [int]($h / 2)) }
    $format = $formats[$fourcc]
    $key = "$($file.DirectoryName)|$w|$h|$format"
    if (-not $groups.ContainsKey($key)) { $groups[$key] = New-Object Collections.Generic.List[string] }
    $groups[$key].Add($file.FullName)
    $found++; $before += $file.Length
}
Write-Host "$found textures to shrink ($([Math]::Round($before / 1GB, 1)) GB), $skipped left as they are."

# ---------------------------------------------------------------------------- shrinking

Step "Shrinking (this takes a while)"
$done = 0; $failed = 0; $after = 0; $n = 0
foreach ($key in $groups.Keys) {
    $n++
    $dir, $w, $h, $format = $key.Split('|')
    $files = $groups[$key]
    if (Test-Path $Temp) { Remove-Item $Temp -Recurse -Force }
    New-Item -ItemType Directory -Force $Temp | Out-Null
    $list = Join-Path $Temp "files.txt"
    [IO.File]::WriteAllLines($list, $files)

    $targs = @("-nologo", "-y", "-dx9", "-m", "0", "-if", "FANT", "-w", $w, "-h", $h, "-o", $Temp, "-flist", $list)
    if ($format) { $targs += @("-f", $format) }
    & $texconv @targs | Out-Null

    foreach ($path in $files) {
        $result = Join-Path $Temp ([IO.Path]::GetFileNameWithoutExtension($path) + ".dds")
        # mod folder names can hold [ ], which plain paths would treat as wildcards
        if ((Test-Path -LiteralPath $result) -and (Get-Item -LiteralPath $result).Length -gt 128) {
            $after += (Get-Item -LiteralPath $result).Length
            Move-Item -LiteralPath $result -Destination $path -Force
            $done++
        } else {
            $failed++
        }
    }
    if ($n % 50 -eq 0) { Write-Host "  $done of $found" }
}
if (Test-Path $Temp) { Remove-Item $Temp -Recurse -Force }
Write-Host "$done shrunk, $failed kept at full size (texconv could not read them)."
Write-Host "Saved $([Math]::Round(($before - $after) / 1GB, 1)) GB."

# OpenMW 477M reads this and then leaves its own texture shrinking off
@(
    "Textures over $MaxSize pixels shrunk by RG477M-Morrowind-LowRes.ps1 on $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
    "$done shrunk, $failed kept at full size, $skipped skipped"
) | Set-Content (Join-Path $Momw "lowres.txt")

# ---------------------------------------------------------------------------- zip

if ($NoZip) { return }
Step "Zipping"
$zipFile = Join-Path $Work "Morrowind Android.zip"
if (Test-Path $zipFile) { Remove-Item $zipFile -Force }
tar.exe -a -c -f $zipFile -C $Work "Morrowind Android"
if ($LASTEXITCODE -ne 0) { Fail "Making the zip failed ($LASTEXITCODE)." }
Write-Host ""
Write-Host "Ready: $zipFile ($([Math]::Round((Get-Item $zipFile).Length / 1GB, 1)) GB)" -ForegroundColor Green
Write-Host "Replace Internal storage\Documents\Morrowind Android on the RG477M with it."
