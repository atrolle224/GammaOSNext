# RG477M-Morrowind.ps1: a modding-openmw.com mod list, installed and set up on this PC with
# umo and momw-configurator, then turned into a "Morrowind Android" folder for OpenMW 477M:
#
#   Morrowind Android\Data Files    the game's own files (from your Morrowind install)
#   Morrowind Android\OpenMWMods    every mod of the list
#   Morrowind Android\momw          openmw.cfg (load order, Android paths), settings.cfg,
#                                   navmesh.db and list.txt, which OpenMW 477M reads
#
# Copy that folder to Internal storage\Documents on the RG477M (or unzip the zip there).
#
# Run it in PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\RG477M-Morrowind.ps1
# It can be run again: finished steps are skipped and umo resumes its downloads.

param(
    [string]$Work = "C:\Morrowind477M",
    [string]$Morrowind = "C:\Program Files (x86)\Steam\steamapps\common\Morrowind",
    [string]$List = "expanded-vanilla",
    [string]$ListName = "Expanded Vanilla",
    [string]$Android = "/storage/emulated/0/Documents/Morrowind Android"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Out = Join-Path $Work "Morrowind Android"
$Mods = Join-Path $Out "OpenMWMods"
$Momw = Join-Path $Out "momw"
$Cache = Join-Path $Work "cache"
$Tools = Join-Path $Work "tools"
$Downloads = Join-Path $env:USERPROFILE "Downloads"
$PcConfig = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "My Games\OpenMW"

function Step($text) { Write-Host ""; Write-Host "== $text" -ForegroundColor Cyan }
function Ask($text) { (Read-Host "$text [Y/n]") -notmatch '^[nN]' }
function Fail($text) { Write-Host $text -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------------------- checks

Step "Checking Morrowind and disk space"
$dataFiles = Join-Path $Morrowind "Data Files"
foreach ($esm in "Morrowind.esm", "Tribunal.esm", "Bloodmoon.esm") {
    if (-not (Test-Path (Join-Path $dataFiles $esm))) { Fail "$esm is missing in $dataFiles. Install Morrowind GOTY from Steam first." }
}
New-Item -ItemType Directory -Force $Work, $Out, $Mods, $Momw, $Cache, $Tools | Out-Null
$drive = (Get-Item $Work).PSDrive
$freeGb = [math]::Round($drive.Free / 1GB)
Write-Host "Free on ${drive}: $freeGb GB. The list and its download cache need about 60 GB;"
Write-Host "the cache ($Cache) can be deleted at the end."
if ($freeGb -lt 60 -and -not (Ask "Less than 60 GB free. Continue anyway?")) { exit 1 }

# ---------------------------------------------------------------------------- OpenMW 0.51 (for its import and navmesh tools)

Step "OpenMW 0.51 for Windows"
function Find-OpenMW {
    $roots = @("C:\Program Files\OpenMW*", "C:\Program Files (x86)\OpenMW*", (Join-Path $Work "openmw*"))
    Get-ChildItem $roots -Recurse -Filter "openmw-iniimporter.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
}
$importer = Find-OpenMW
if (-not $importer) {
    $headers = @{ "User-Agent" = "RG477M-Morrowind" }
    $release = Invoke-RestMethod "https://api.github.com/repos/OpenMW/openmw/releases?per_page=30" -Headers $headers |
        Where-Object { $_.tag_name -match '^openmw-0\.51' -and -not $_.prerelease } | Select-Object -First 1
    if (-not $release) { Fail "No OpenMW 0.51 release found; install it from https://openmw.org/downloads/ and run this again." }
    $zip = $release.assets | Where-Object { $_.name -match 'win64.*\.zip$' } | Select-Object -First 1
    if ($zip) {
        $file = Join-Path $Cache $zip.name
        Write-Host "Downloading $($zip.name)"
        Invoke-WebRequest $zip.browser_download_url -OutFile $file -Headers $headers
        Expand-Archive $file (Join-Path $Work "openmw") -Force
    } else {
        $exe = $release.assets | Where-Object { $_.name -match 'win64.*\.exe$' } | Select-Object -First 1
        if (-not $exe) { Fail "No Windows download in $($release.tag_name); install OpenMW 0.51 from https://openmw.org/downloads/." }
        $file = Join-Path $Cache $exe.name
        Write-Host "Downloading $($exe.name); its installer opens next: install with the defaults."
        Invoke-WebRequest $exe.browser_download_url -OutFile $file -Headers $headers
        Start-Process $file -Wait
    }
    $importer = Find-OpenMW
    if (-not $importer) { Fail "openmw-iniimporter.exe not found after installing OpenMW." }
}
$navmeshtool = Join-Path $importer.DirectoryName "openmw-navmeshtool.exe"
Write-Host "OpenMW tools: $($importer.DirectoryName)"

# ---------------------------------------------------------------------------- MOMW Tools Pack (umo, momw-configurator)

Step "MOMW Tools Pack (umo and momw-configurator)"
function Find-Tool($name) {
    Get-ChildItem $Tools -Recurse -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1
}
$umo = Find-Tool "umo.exe"
if (-not $umo) {
    $pack = Get-ChildItem $Downloads -Filter "*momw-tools-pack*.zip" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $pack) {
        Write-Host "Opening the MOMW Tools Pack page: download the Windows zip to your Downloads folder."
        Start-Process "https://modding-openmw.gitlab.io/momw-tools-pack/"
        while (-not $pack) {
            Start-Sleep 5
            $pack = Get-ChildItem $Downloads -Filter "*momw-tools-pack*.zip" -ErrorAction SilentlyContinue |
                Where-Object { $_.Length -gt 0 } | Select-Object -First 1
        }
        Start-Sleep 5
    }
    Expand-Archive $pack.FullName $Tools -Force
    $umo = Find-Tool "umo.exe"
    if (-not $umo) { Fail "umo.exe is not in $($pack.Name)." }
}
$configurator = Find-Tool "momw-configurator.exe"
if (-not $configurator) { Fail "momw-configurator.exe is not in the tools pack." }
Write-Host "Tools: $($umo.DirectoryName)"
# umo and the configurator expect to be run from their own folder
Set-Location $umo.DirectoryName

# ---------------------------------------------------------------------------- the game's own files

Step "Morrowind's Data Files"
$vanilla = Join-Path $Out "Data Files"
robocopy $dataFiles $vanilla /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Fail "Copying Data Files failed (robocopy $LASTEXITCODE)." }
Copy-Item (Join-Path $Morrowind "Morrowind.ini") $Out -Force

# ---------------------------------------------------------------------------- umo: download and install the list

Step "umo: Nexus Mods sign-in"
Write-Host "umo asks for three things. Answer with:"
Write-Host "  - Nexus: your browser opens; sign in and allow umo, then come back here."
Write-Host "  - mod list folder:  $Mods" -ForegroundColor Yellow
Write-Host "  - download cache:   $Cache" -ForegroundColor Yellow
if (Ask "Run umo setup now (say n if you already did it for $Mods)?") {
    & $umo.FullName setup
    if ($LASTEXITCODE -ne 0) { Fail "umo setup stopped ($LASTEXITCODE)." }
}

Step "umo: installing $ListName (this takes hours the first time)"
do {
    & $umo.FullName install --sync $List
    $ok = $LASTEXITCODE -eq 0
    if (-not $ok) { Write-Host "umo stopped ($LASTEXITCODE). Running it again resumes where it left off." -ForegroundColor Yellow }
} while (-not $ok -and (Ask "Run umo again?"))
if (-not $ok) { Fail "The list isn't fully installed; run this script again to resume." }

# ---------------------------------------------------------------------------- momw-configurator: load order, settings, navmesh

Step "momw-configurator: load order, settings and navmesh"
if (Test-Path $PcConfig) {
    $backup = Join-Path $Work ("pc-openmw-config-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    Copy-Item $PcConfig $backup -Recurse
    Write-Host "Your PC's OpenMW settings were saved to $backup (the configurator replaces them)."
}
Write-Host "If it asks for paths, answer with:"
Write-Host "  - openmw-iniimporter.exe:  $($importer.FullName)" -ForegroundColor Yellow
Write-Host "  - openmw-navmeshtool.exe:  $navmeshtool" -ForegroundColor Yellow
Write-Host "  - Morrowind.ini:           $(Join-Path $Morrowind 'Morrowind.ini')" -ForegroundColor Yellow
Write-Host "  - Morrowind install:       $Morrowind" -ForegroundColor Yellow
Write-Host "The navmesh step can take 30 minutes or more."
& $configurator.FullName config --verbose --run-navmeshtool --run-validator $List
if ($LASTEXITCODE -ne 0) {
    Write-Host "momw-configurator stopped ($LASTEXITCODE)." -ForegroundColor Yellow
    if (-not (Ask "Try again without the navmesh step?")) { exit 1 }
    & $configurator.FullName config --verbose --run-validator $List
    if ($LASTEXITCODE -ne 0) { Fail "momw-configurator failed ($LASTEXITCODE)." }
}

# ---------------------------------------------------------------------------- the Android copy of the configuration

Step "Converting the configuration for the RG477M"
$pcCfg = Join-Path $PcConfig "openmw.cfg"
if (-not (Test-Path $pcCfg)) { Fail "momw-configurator wrote no $pcCfg." }

$outFull = (Resolve-Path $Out).Path.TrimEnd('\')
$vanillaPaths = @((Resolve-Path $dataFiles).Path.TrimEnd('\'), $vanilla.TrimEnd('\'))
$extra = Join-Path $Momw "extra"
$extraCount = 0
$lines = New-Object System.Collections.Generic.List[string]
$counts = @{ data = 0; content = 0; groundcover = 0; "fallback-archive" = 0 }

function To-Android([string]$path) {
    $full = [IO.Path]::GetFullPath($path).TrimEnd('\')
    foreach ($v in $vanillaPaths) {
        if ($full -ieq $v -or $full -imatch '\\ModdingResources\\Morrowind\\Data Files$') { return "$Android/Data Files" }
    }
    if ($full.StartsWith($outFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
        return $Android + "/" + $full.Substring($outFull.Length + 1).Replace('\', '/')
    }
    # a folder the configurator made outside the list (merged plugins and the like): copied along
    $script:extraCount++
    $name = "{0:D2} {1}" -f $script:extraCount, (Split-Path $full -Leaf)
    robocopy $full (Join-Path $extra $name) /E /NFL /NDL /NJH /NJS /NP | Out-Null
    Write-Host "  copied $full -> momw\extra\$name"
    return "$Android/momw/extra/$name"
}

foreach ($raw in Get-Content $pcCfg) {
    $line = $raw.Trim()
    if ($line -notmatch '^(data|content|groundcover|fallback-archive)\s*=\s*(.*)$') { continue }
    $key = $Matches[1]; $value = $Matches[2].Trim()
    if ($key -eq "data") {
        $path = $value.Trim('"').Replace('&&', '&')
        if (-not (Test-Path $path)) { Write-Host "  missing folder, skipped: $path" -ForegroundColor Yellow; continue }
        $value = '"' + (To-Android $path).Replace('&', '&&') + '"'
    }
    $lines.Add("$key=$value")
    $counts[$key]++
}
if ($counts.data -eq 0 -or $lines[0] -notmatch '/Data Files"$') {
    Fail "The converted openmw.cfg does not start with Morrowind's Data Files; check $pcCfg."
}
[IO.File]::WriteAllLines((Join-Path $Momw "openmw.cfg"), $lines)
Copy-Item (Join-Path $PcConfig "settings.cfg") $Momw -Force -ErrorAction SilentlyContinue
$navmesh = Get-ChildItem $PcConfig -Filter "navmesh.db" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($navmesh) { Copy-Item $navmesh.FullName $Momw -Force } else { Write-Host "  no navmesh.db (OpenMW builds it while you play)" }
[IO.File]::WriteAllText((Join-Path $Momw "list.txt"), "$ListName ($List, modding-openmw.com)")
Write-Host ("openmw.cfg: {0} folders, {1} plugins, {2} groundcover, {3} archives" -f `
    $counts.data, $counts.content, $counts.groundcover, $counts["fallback-archive"])

# ---------------------------------------------------------------------------- done

$sizeGb = [math]::Round(((Get-ChildItem $Out -Recurse -File | Measure-Object Length -Sum).Sum) / 1GB, 1)
Step "Ready: $Out ($sizeGb GB)"
Write-Host "Copy the whole 'Morrowind Android' folder to the RG477M's Internal storage\Documents"
Write-Host "(a USB cable to the PC is the fastest way). Then start OpenMW 477M."
if (Ask "Also make a zip of it ($Work\Morrowind Android.zip; slow for $sizeGb GB)?") {
    tar.exe -a -c -f (Join-Path $Work "Morrowind Android.zip") -C $Work "Morrowind Android"
    if ($LASTEXITCODE -ne 0) { Fail "Making the zip failed ($LASTEXITCODE)." }
    Write-Host "Zip: $Work\Morrowind Android.zip"
}
Write-Host "The download cache $Cache can be deleted now."
