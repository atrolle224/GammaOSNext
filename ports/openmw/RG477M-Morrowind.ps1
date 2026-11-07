# RG477M-Morrowind.ps1: a modding-openmw.com mod list, installed and set up on this PC with
# umo and momw-configurator, then turned into a "Morrowind Android" folder for OpenMW 477M:
#
#   Morrowind Android\Data Files    the game's own files (from your Morrowind install)
#   Morrowind Android\OpenMWMods    every mod of the list
#   Morrowind Android\momw          openmw.cfg (load order, Android paths), settings.cfg,
#                                   navmesh.db and list.txt, which OpenMW 477M reads
#
# For Expanded Vanilla it builds the RG477M version: no menu or intro videos, no optional HD
# texture folders, normal grass density, no volumetric clouds, and every texture over 1024
# pixels shrunk (RG477M-Morrowind-LowRes.ps1, which must sit next to this script).
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

# ---------------------------------------------------------------------------- the RG477M version of the list

# momw-configurator applies these to the list (modding-openmw.com/tips/customizing-modlists):
# the menu and intro videos, the optional HD texture folders (each mod keeps its normal
# textures), thicker grass and volumetric clouds are left out for the handheld. Water, swamps
# and skies stay vanilla: scum moved onto the water plane and the reshaped Seyda Neen pools
# flicker on the RG477M's GPU.
$customizations = @'
[[Customizations]]
listName = 'expanded-vanilla'
removeData = [
  'VvardenfellAnimatedMainMenu\00 Animated Main Menu',
  'HDIntroCinematicEnglish',
  'OAABData\HD',
  'Cutting Room Floor - High Resolution Textures',
  'WhiteSuran2MDEdition\03 HD Textures',
  'ImprovedBetterSkulls\02a Vanilla Textures 2x-4x Texture Size',
  'OpenMWVanillaFriendlyAnimatedBasketEdit\01 HD Textures',
  'MageRobes\04 HD Textures',
  'OAABPomegranates\02 HD Textures',
  'BeautifulCitiesofMorrowind\06 HD Textures',
  'OAABGrazelands\03 HD Textures',
  'OAABTelMora\02 HD Textures',
  'ByAzura\01 High Res Textures',
  'AlmalexiaRedone\HD',
  'TheMananautsMessage\03 HD Textures',
  'RedWisdomAnAshlanderProphecy\01 HD Textures',
  'SecretsoftheCrystalCity\01 HD Textures',
  'GreymarchDawnWhispersofJyggalag\01 HD Textures',
  'TheSearchfortheWhiteWave\02 HD Textures',
  'CalderaPrioryandtheDepthsofBloodandBone\HD',
  'TempleMaster\04 HD Textures',
  'ThePopularPlague\02 HD Textures',
  'UpscaledJournalandBookmarkBGReplacement\01 2x Resolution Textures',
  'GlowintheDahrk\01 Hi Res Window Texture Replacer',
  'RemirosGroundcover\01b Thicker Grass OpenMW',
  'MOMWPostProcessingPack\00 RecommendedConfig',
  'MOMWPostProcessingPack\03 ZesterersVolumetricClouds',
  'PerfectScum',
  'MOMWPatches\23 Little Landscapes Seyda Neen Swamp Pools Patched',
  'BetterWaterfalls\00 Core',
  'BetterWaterfalls\02 Tamriel Rebuilt Water',
  'OpenMWMoreDynamicWaterMeshes',
  'SkiesIV\Skies - .IV',
  'SkiesIV\Particles',
  'NewStarfields\00 Core',
  'NewStarfields\01 Option 7 (100% Opacity)',
  'DyingWorldsmoonsretexture\Data Files',
  'SophiasClearBlueSkies',
]
removeContent = [
  'PR Perfect Scum.esp',
  'Little Landscapes - Seyda Neen Swamp Pools.ESP',
]
'@

# ---------------------------------------------------------------------------- momw-configurator: load order, settings, navmesh

Step "momw-configurator: load order, settings and navmesh"
if (Test-Path $PcConfig) {
    $backup = Join-Path $Work ("pc-openmw-config-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    Copy-Item $PcConfig $backup -Recurse
    Write-Host "Your PC's OpenMW settings were saved to $backup (the configurator replaces them)."
}
$customFile = Join-Path $PcConfig "momw-customizations.toml"
if ($List -eq "expanded-vanilla") {
    New-Item -ItemType Directory -Force $PcConfig | Out-Null
    [IO.File]::WriteAllText($customFile, $customizations)
    Write-Host "RG477M changes to the list: $customFile"
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
# made again from the configurator's list each run, so folders it no longer uses go
if (Test-Path $extra) { Remove-Item -LiteralPath $extra -Recurse -Force }
Remove-Item -LiteralPath (Join-Path $Momw "lowres.txt") -ErrorAction SilentlyContinue
$extraCount = 0
$lines = New-Object System.Collections.Generic.List[string]
$problems = New-Object System.Collections.Generic.List[string]
$pcData = New-Object System.Collections.Generic.List[string]
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

# menu and intro video replacers: their Bink videos don't play in OpenMW for Android
$leftOut = @("00 Animated Main Menu", "HDIntroCinematicEnglish")

foreach ($raw in Get-Content $pcCfg) {
    $line = $raw.Trim()
    if ($line -notmatch '^(data|content|groundcover|fallback-archive)\s*=\s*(.*)$') { continue }
    $key = $Matches[1]; $value = $Matches[2].Trim()
    if ($key -eq "data") {
        $path = $value.Trim('"').Replace('&&', '&')
        if ($leftOut -contains (Split-Path $path -Leaf)) { Write-Host "  left out $path"; continue }
        if (-not (Test-Path $path)) { $problems.Add("missing mod folder: $path"); continue }
        $pcData.Add($path)
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

# ---------------------------------------------------------------------------- checks

Step "Checking the mod list"
# every plugin and grass file must be in one of the data folders; OpenMW takes a file from the
# last folder that has it, as it will on the RG477M
$plugins = $lines | Where-Object { $_ -match '^(content|groundcover|fallback-archive)=' }
foreach ($entry in $plugins) {
    $file = $entry.Substring($entry.IndexOf('=') + 1).Trim().Trim('"')
    $found = $false
    for ($i = $pcData.Count - 1; $i -ge 0 -and -not $found; $i--) {
        if (Test-Path -LiteralPath (Join-Path $pcData[$i] $file)) { $found = $true }
    }
    if (-not $found -and $file -notmatch '^(Morrowind|Tribunal|Bloodmoon)\.(esm|bsa)$') {
        $problems.Add("not in any mod folder: $entry")
    }
}
# the same plugins, in the same order, as the configurator's load order
$pcOrder = Get-Content $pcCfg | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^(content|groundcover)\s*=' } |
    ForEach-Object { ($_ -replace '\s*=\s*', '=') }
$outOrder = $lines | Where-Object { $_ -match '^(content|groundcover)=' }
if (($pcOrder -join "`n") -ne ($outOrder -join "`n")) { $problems.Add("the plugin order differs from the configurator's openmw.cfg") }
# grass needs the plugins and [Groundcover] enabled = true
$settingsOut = Join-Path $Momw "settings.cfg"
if ($counts.groundcover -gt 0 -and (Test-Path $settingsOut)) {
    $section = ""; $grassOn = $null
    foreach ($l in Get-Content $settingsOut) {
        $t = $l.Trim()
        if ($t -match '^\[(.+)\]$') { $section = $Matches[1] }
        elseif ($section -ieq "Groundcover" -and $t -match '^enabled\s*=\s*(\S+)') { $grassOn = $Matches[1] }
    }
    if ($grassOn -and $grassOn -ine "true") { $problems.Add("settings.cfg has [Groundcover] enabled = $grassOn though the list has $($counts.groundcover) grass plugins") }
}
$report = @(
    "$ListName ($List)",
    ("{0} folders, {1} plugins, {2} grass plugins, {3} archives" -f $counts.data, $counts.content, $counts.groundcover, $counts["fallback-archive"]),
    "",
    "Load order:"
) + ($lines | Where-Object { $_ -match '^(content|groundcover|fallback-archive)=' })
if ($problems.Count -gt 0) { $report = @("PROBLEMS:") + $problems + @("") + $report }
[IO.File]::WriteAllLines((Join-Path $Momw "check.txt"), $report)
if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "Run this script again to resume umo; the list in momw\check.txt" -ForegroundColor Red
} else {
    Write-Host "All folders and plugins present, in the configurator's order (momw\check.txt)." -ForegroundColor Green
}

# ---------------------------------------------------------------------------- handheld textures

Step "Shrinking textures over 1024 pixels"
$lowRes = Join-Path $PSScriptRoot "RG477M-Morrowind-LowRes.ps1"
if (Test-Path $lowRes) {
    & $lowRes -Work $Work -NoZip
} else {
    Write-Host "RG477M-Morrowind-LowRes.ps1 is not next to this script; textures stay full size." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------- done

$sizeGb = [math]::Round(((Get-ChildItem $Out -Recurse -File | Measure-Object Length -Sum).Sum) / 1GB, 1)
Step "Ready: $Out ($sizeGb GB)"
Write-Host "Copy the whole 'Morrowind Android' folder to the RG477M's Internal storage\Documents"
Write-Host "(a USB cable to the PC is the fastest way). Then start OpenMW 477M."
Step "Zipping (a while for $sizeGb GB)"
$zipFile = Join-Path $Work "Morrowind Android.zip"
Remove-Item -LiteralPath $zipFile -ErrorAction SilentlyContinue
tar.exe -a -c -f $zipFile -C $Work "Morrowind Android"
if ($LASTEXITCODE -ne 0) { Fail "Making the zip failed ($LASTEXITCODE)." }
Write-Host "Zip: $zipFile. Unzip it into Internal storage\Documents on the RG477M."
Write-Host "The download cache $Cache can be deleted now."
