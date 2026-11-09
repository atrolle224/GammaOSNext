# RG477M-Morrowind.ps1: a modding-openmw.com mod list, installed and set up on this PC with
# umo and momw-configurator, then turned into a "Morrowind Android" folder for OpenMW Mali Mobile:
#
#   Morrowind Android\Data Files    the game's own files (from your Morrowind install)
#   Morrowind Android\OpenMWMods    every mod of the list
#   Morrowind Android\momw          openmw.cfg (load order, Android paths), settings.cfg,
#                                   navmesh.db and list.txt, which OpenMW Mali Mobile reads
#
# It builds the RG477M custom list from Expanded Vanilla (see "the RG477M version of the
# list" below) with the fixes, resources and patches it needs (patches for anything left out
# are dropped automatically),
# then shrinks every texture over 1024 pixels (RG477M-Morrowind-LowRes.ps1, which must sit
# next to this script) and adds Skills Start At One.
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
    [string]$Android = "/storage/emulated/0/Documents/Morrowind Android",
    [switch]$KeepStartingSkills
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

# Patches from the mods' own Nexus pages that the list doesn't download (found by
# lists/nexus_patch_scan.py), fetched through umo's custom list with your Nexus account and
# copied to Extra, which the conversion loads after the list.
$extraPatches = @(
    @{ Name = "TMR Patch for OAAB Tel Mora"; Link = "nxm://morrowind/mods/52278/files/1000054494?key=&expires=&user_id=" }
)
if ($List -eq "expanded-vanilla") {
    Step "Patches the list doesn't download"
    foreach ($patch in $extraPatches) {
        $target = Join-Path (Join-Path $Work "Extra") $patch.Name
        if (Test-Path $target) { Write-Host "  $($patch.Name): already in Extra"; continue }
        $before = Get-Date
        & $umo.FullName add $patch.Link
        $plugin = Get-ChildItem $Tools, $Mods -Recurse -File -Include *.esp, *.esm, *.omwaddon -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $before -or $_.CreationTime -gt $before } | Select-Object -First 1
        if ($LASTEXITCODE -ne 0 -or -not $plugin) {
            Write-Host "  $($patch.Name) could not be downloaded; get it from its Nexus page into $target to add it." -ForegroundColor Yellow
            continue
        }
        robocopy $plugin.DirectoryName $target /E /NFL /NDL /NJH /NJS /NP | Out-Null
        Write-Host "  $($patch.Name): $($plugin.Name)"
    }
}

# ---------------------------------------------------------------------------- the RG477M version of the list

# The RG477M custom list: Expanded Vanilla's landmasses, quests, guilds, NPCs, dialogue,
# creatures, new items, cities, groundcover, distant details, caves, dungeons, interiors,
# randomizers and music, a few small exteriors, homes and conveniences, with the fixes,
# resources, mesh optimizations and patches they need; no combat, animation, balance,
# leveling, UI, texture, sky, water or lighting overhauls. Made by lists/make_rg477m_custom.py
# from the list's API data.
$customizations = @'
[[Customizations]]
listName = 'expanded-vanilla'
removeData = [
  '''TexturePacks\MorrowindEnhancedTextures\MET 6-1 main''',
  '''TexturePacks\MorrowindEnhancedTextures\Interface''',
  '''TexturePacks\MorrowindEnhancedTextures\atlas''',
  '''TexturePacks\TheDoorsofOblivionFullUpscale\main''',
  '''TexturePacks\TheDoorsofOblivionFullUpscale\GraphicHerbalism''',
  '''TexturePacks\TheDoorsofOblivionFullUpscale\GraphicHerbalism\00 Core''',
  '''TexturePacks\SophiesSkoomaSweetshoppe\07 Telvanni Cephalopod Armor TD Cuirass Upscale and Color Match''',
  '''TexturePacks\SophiesSkoomaSweetshoppe\21 Akulukhan's Best Chamber OpenMW''',
  '''TexturePacks\SophiesSkoomaSweetshoppe\23 Telvanni Mushroomtop Housepod UV Fix''',
  '''TexturePacks\SophiesSkoomaSweetshoppe\10 Shadow Mimicry's Backpack Retexture (host for modding-openmw.com)''',
  '''TexturePacks\SophiesSkoomaSweetshoppe\16 QCVL Blood Altar x Diverse Blood Fix''',
  '''TexturePacks\SophiesSkoomaSweetshoppe\11 SophiasClearBlueSkies''',
  '''TexturePacks\SophiesSkoomaSweetshoppe\30 Temporary Fixes''',
  '''Architecture\WhiteSuran2MDEdition\00 Core''',
  '''Architecture\WhiteSuran2MDEdition\02 Glow in the Dahrk''',
  '''Architecture\WhiteSuran2MDEdition\03 HD Textures''',
  '''Architecture\DwemerMeshImprovement''',
  '''Architecture\DwemerMeshImprovementsRevamped''',
  '''Architecture\GhastlyGlowyfence''',
  '''Architecture\DragonStatueRevisited\00 Core''',
  '''Architecture\DragonStatueReRevistedDeGoofifiedEdition\Dragon Statue Re-Revisted (De-Goofified Edition)''',
  '''Architecture\UniqueBannersandSignsReplacer''',
  '''Architecture\UniqueTavernSignsforTamrielRebuilt''',
  '''Architecture\Swayland''',
  '''Architecture\Nordsshutyourwindows\00 Core''',
  '''Architecture\Nordsshutyourwindows\03 Vanilla style sunrays''',
  '''Architecture\NecromArkitektoraofMorrowind\HQ''',
  '''Architecture\NecromArkitektoraofMorrowind\NecromMinorMeshesFixes''',
  '''Flora\ParasolParticles\01 OAAB_Data Patch''',
  '''Trees\SMBitterCoastTreeReplacer\SM_BCTree_1_0\Data files''',
  '''Environment\ILavaGoodMeshReplacer\00 Lava''',
  '''Environment\ILavaGoodMeshReplacer\01 Hot Oil''',
  '''Environment\ILavaGoodMeshReplacer\03 Tamriel_Data Patch''',
  '''Environment\SubtleSmoke''',
  '''Environment\CorrectUVRocks\Data Files''',
  '''Environment\PerfectScum''',
  '''Environment\BetterWaterfalls\00 Core''',
  '''Environment\BetterWaterfalls\02 Tamriel Rebuilt Water''',
  '''Environment\OpenMWMoreDynamicWaterMeshes''',
  '''SkiesandWeather\SkiesIV\Skies - .IV''',
  '''SkiesandWeather\SkiesIV\Particles''',
  '''SkiesandWeather\NewStarfields\00 Core''',
  '''SkiesandWeather\NewStarfields\01 Option 7 (100% Opacity)''',
  '''SkiesandWeather\DyingWorldsmoonsretexture\Data Files''',
  '''SkiesandWeather\Meteors''',
  '''Lighting\ImprovedLightsforAllShaders\00 Core''',
  '''Lighting\ImprovedLightsforAllShaders\01 Smoke and Steam Emitters''',
  '''Lighting\ImprovedLightsforAllShadersPatchHub\Properly Smoothed Meshes''',
  '''Lighting\ImprovedLightsforAllShadersPatchHub\Tamriel Data''',
  '''Lighting\ImprovedLightsforAllShadersPatchHub\Dwemer Mesh Improvement''',
  '''Lighting\GlowintheDahrk\00 Core''',
  '''Lighting\GlowintheDahrk\01 Hi Res Window Texture Replacer''',
  '''Lighting\GlowintheDahrk\04 Raven Rock Glass Windows''',
  '''Lighting\GlowintheDahrk\07 Telvanni Tower Interior Glow OpenMW''',
  '''Lighting\HarvestLights''',
  '''Lighting\OpenMWLeaveTheLightsOff\LeaveTheLightsOff''',
  '''Lighting\HeldLightBoost\Held Light Boost''',
  '''FurnitureandClutter\OpenMWvanillacandlespatchedwithEnlightenedFlamesandILFAS''',
  '''FurnitureandClutter\DunmerLanternsReplacer\01 Glow Effect''',
  '''FurnitureandClutter\DunmerLanternsReplacer\03 Ashlander Lanterns Retexture 1''',
  '''FurnitureandClutter\DunmerLanternsReplacer\04 Tamriel_Data Patch - Glow Effect''',
  '''FurnitureandClutter\DunmerLanternsReplacer\05 OAAB_Data Patch - Glow Effect''',
  '''FurnitureandClutter\ImprovedBetterSkulls\Data Files''',
  '''FurnitureandClutter\ImprovedBetterSkulls\Vanilla Textures''',
  '''FurnitureandClutter\ImprovedBetterSkulls\02a Vanilla Textures 2x-4x Texture Size''',
  '''FurnitureandClutter\OpenMWContainersAnimated\Containers Animated''',
  '''FurnitureandClutter\OpenMWContainersAnimated\Optional\kollops''',
  '''FurnitureandClutter\OpenMWVanillaFriendlyAnimatedBasketEdit\00 Core''',
  '''FurnitureandClutter\OpenMWVanillaFriendlyAnimatedBasketEdit\01 HD Textures''',
  '''FurnitureandClutter\KnowThyAncestors''',
  '''FurnitureandClutter\Dunmersashpits\Data files''',
  '''FurnitureandClutter\HowIShotWeb\How I Shot Web''',
  '''FurnitureandClutter\TheMadstone''',
  '''Weapons\CorrectIronWarhammer\Data Files''',
  '''Weapons\OrientalMeshImprovements''',
  '''Weapons\WeaponSheathing\Data Files''',
  '''Weapons\WeaponSheathingAdditions''',
  '''Weapons\SWJsWeaponSheathingPatches\Oriental Mesh Improvements''',
  '''Weapons\RacersandSloadandSlaversWeaponSheathingPatch''',
  '''Weapons\ImprovedThrownWeaponProjectiles\Data Files''',
  '''VFX\OpenMWDynamicAmbientVisualEffects''',
  '''VFX\Fireflies''',
  '''VFX\NoShieldSparkle''',
  '''VFX\DiverseBloodOpenMWLua''',
  '''VFX\SubtleMagicGlow\fade''',
  '''VFX\OpenMWImpactEffects''',
  '''VFX\Mistify\00 Core''',
  '''Animation\OntheBlink\On the Blink\Data Files''',
  '''Animation\SimplyWalkingRemastered\Simply Walking (WS Edition)''',
  '''Animation\Justalittlebitbetteranimationsforthemagebuildfirstperson''',
  '''Animation\Justalittlebitbetteranimationsforthemagebuildfirstperson\animations\xbase_anim.1st''',
  '''Animation\ReAnimationv3Completefirstpersonanimationpack\00 Core''',
  '''Animation\ReAnimationv3Completefirstpersonanimationpack\02 Thrown Weapon Projectiles Fix''',
  '''Animation\3rdPersonaltAttacks''',
  '''Animation\OpenMWDynamicAnimations\3rdPersonPatch''',
  '''Animation\openmwanimatedlevitation''',
  '''Audio\CharacterSoundOverhaul''',
  '''Audio\CharacterSoundOverhaul\Higher Bitrate Sounds''',
  '''Audio\openmwfootsteps''',
  '''Exteriors\OAABTheAshenDivide''',
  '''Exteriors\ValleyoftheWindOverhaul\Valley of the Wind Overhaul''',
  '''Exteriors\FacesofVelAshMire\Data Files''',
  '''Exteriors\ARiverofFire''',
  '''Exteriors\SouthernAshlandsOverhaul''',
  '''Exteriors\ConceptArtMolagAmurRegionTheGreatScathes\00 Core''',
  '''Exteriors\TheMountainofFear''',
  '''Exteriors\BallakuTheLonelyTowers''',
  '''Exteriors\SuranAshlandsBarrier''',
  '''Exteriors\WitnessStructureTheSeawallofVivec\00 Core''',
  '''Exteriors\WitnessStructureTheSeawallofVivec\03 Little Landscapes Vivec Islands Patch''',
  '''Exteriors\VivecLighthouse\00 Core''',
  '''Exteriors\CompatibleOdaiRiverUpperOverhaul\Compatible Odai River Upper Overhaul 1.2\Compatible Odai River Upper Overhaul''',
  '''Exteriors\TheGroveofBenAbi''',
  '''Exteriors\TheGroveofBenAbiEnhanced''',
  '''Exteriors\AzurasCoastRedone''',
  '''Exteriors\OAABDwemerPavements\00 Core''',
  '''Exteriors\OAABDwemerPavements\01 Trackless Grazelands Patch''',
  '''Exteriors\OAABPomegranates\00 Core''',
  '''Exteriors\OAABPomegranates\02 HD Textures''',
  '''Exteriors\OAABPomegranates\03 SSQN OpenMW''',
  '''BodiesandHeads\FamiliarFacesbyCaleb''',
  '''BodiesandHeads\FaceliftforTamrielData''',
  '''Gameplay\StatsPotionsTrainingLimitsOpenMWOblivionStyleIncluded''',
  '''Gameplay\BestFriendsForeverOpenMW''',
  '''Gameplay\FriendlierFireOpenMW''',
  '''Gameplay\DynamicTimescaleforOpenMW\DynamicTimescale''',
  '''Gameplay\GoHome''',
  '''Gameplay\LightHotkey''',
  '''Gameplay\ShieldUnequipper''',
  '''Gameplay\ConvenientThiefTools''',
  '''Gameplay\NoWitnessNoBounty''',
  '''Gameplay\PerfectPlacement''',
  '''Gameplay\ProtectedBeasts\00 Core''',
  '''Gameplay\ProtectedBeasts\01 Argonian Full Helms''',
  '''Gameplay\ProtectedBeasts\02 Argonian Full Helms Tamriel Data''',
  '''Gameplay\ProtectedBeasts\03 Boots for Beasts''',
  '''Gameplay\ProtectedBeasts\04 Boots for Beasts Tamriel Data''',
  '''Gameplay\ProtectedBeasts\05 Hist Helms''',
  '''Gameplay\SneakisGoodNowOpenMW''',
  '''Gameplay\SneakFatigueDrainOpenMW''',
  '''Gameplay\StateBasedMagickaRegenSBMR\00 Core''',
  '''Gameplay\ReadingOverhaulOpenMW''',
  '''Gameplay\FreshLootOpenMW\00 Core''',
  '''Gameplay\SmartAmmoforOpenMWLua''',
  '''Balance\BetterArmorTrainingOpenMW''',
  '''Balance\ImmersiveTelvanniBugMusk''',
  '''Balance\MDMDMoreDeadlyMorrowindDenizens''',
  '''Balance\BewaretheSixthHouseSixthHouseOverhaul\Modular''',
  '''Balance\TribunalRebalance''',
  '''Balance\BloodmoonRebalance\Bloodmoon Rebalance''',
  '''Balance\FortheRightPrice\For the Right Price\Modular''',
  '''Balance\BetterMerchantsSkillsOpenMW\00 Core''',
  '''Balance\OwnershipOverhaul''',
  '''Balance\RealDisposition''',
  '''Balance\FatigueandSpeedandCarryweightRebalanceOpenMW''',
  '''Balance\PickpocketRebalanceOpenMW''',
  '''Balance\BetterBlight''',
  '''Balance\ExpandingBlightOpenMW''',
  '''Balance\ExpandingBlightOpenMW\deadly-blight-openmw-lua''',
  '''Balance\DaedraUseBoundEquipmentforOpenMW''',
  '''Balance\BoundBalance''',
  '''Balance\SoullessSummons''',
  '''Balance\BetterVampiresVampireOverhaulforOpenMW''',
  '''Balance\BetterVampiresVampireOverhaulforOpenMW\optimized''',
  '''Balance\MagicRebalanceandFixesMRF\00 Core''',
  '''Balance\MagicRebalanceandFixesMRF\01 Patches''',
  '''Balance\MagicRebalanceandFixesMRF\02 OpenMW Lua''',
  '''Balance\MagicRebalanceandFixesMRF\03 No more Dr Nerevarine''',
  '''Balance\BetterBalancedTauntandPersuasionBBTaP\TR PT\00 Core''',
  '''Balance\BetterBalancedTauntandPersuasionBBTaP\TR PT\01 Patches''',
  '''Balance\BetterBalancedTauntandPersuasionBBTaP\TR PT\02 Addons''',
  '''Balance\SaneCustomPotionsOpenMW''',
  '''Balance\SolthasSixthHouseAmulet\Solthas Sixth House Amulet''',
  '''Combat\NGardeActiveBlockandParryOpenMW\NGarde''',
  '''Combat\MoveLikeThisDirectionalAttacksOpenMW''',
  '''Combat\IronFistforOpenMW\Iron Fist for OpenMW''',
  '''Combat\BullseyeMarksmanOverhaulOpenMW''',
  '''Combat\ArrowStickOpenMW''',
  '''Combat\TakeCoverOpenMW\00 Core''',
  '''Combat\FairCareOpenMW\00 Core''',
  '''MagicSpells\DaisysLuaMultimark''',
  '''MagicSpells\LoafysNecromancyReanimateDeadOpenMW51''',
  '''Leveling\NaturalCharacterGrowth\00 Core''',
  '''Leveling\NaturalCharacterGrowth\01 NCG - Normal''',
  '''Leveling\SkillEvolution\00 Core''',
  '''RacesandBirthsigns\RacesRESPECtedARaceSkillandAttributeRebalanceMod''',
  '''RacesandBirthsigns\BirthsignsRESPECtedABirthsignRebalanceMod''',
  '''Chargen\NoPopUpChargen''',
  '''PlayerHomes\FabulousHlaaloManor''',
  '''PlayerHomes\FabulousHlaaloManor\Options-see-readme''',
  '''PlayerHomes\TheArchmagistersAbode\data files''',
  '''PlayerHomes\RatherNiceFactorsEstate\00 Core''',
  '''PlayerHomes\RatherNiceFactorsEstate\01 Core - Glow in the Dahrk''',
  '''PlayerHomes\RatherNiceFactorsEstate\02 Patch - Patch for Purists 4.0.X''',
  '''PlayerHomes\IndorilMansion''',
  '''Minigames\Nineholes\00 Core''',
  '''Minigames\Nineholes\01 Ald-ruhn, The Rat In The Pot''',
  '''Minigames\Nineholes\04 Ebonheart, Six Fishes''',
  '''Minigames\Nineholes\05 Moonmoth Legion Fort''',
  '''Minigames\Nineholes\06 Pelagiad, Halfway Tavern''',
  '''Minigames\Nineholes\07 Sadrith Mora, Dirty Muriel's Cornerclub''',
  '''Minigames\Nineholes\08 Seyda Neen, Arrille's Tradehouse''',
  '''Minigames\Nineholes\09 (BCOM) Suran, Goldyn Belaram''',
  '''Minigames\Nineholes\10 Vivec, Elven Nations Cornerclub''',
  '''Camera\ActionCameraSwap''',
  '''Camera\OpenMWConsumingAnimated''',
  '''PostProcessingShaders\MOMWPostProcessingPack\00 RecommendedConfig''',
  '''PostProcessingShaders\MOMWPostProcessingPack\01 XE-Shaders''',
  '''PostProcessingShaders\MOMWPostProcessingPack\02 OMWFX-Shaders''',
  '''PostProcessingShaders\MOMWPostProcessingPack\03 ZesterersVolumetricClouds''',
  '''PostProcessingShaders\MOMWPostProcessingPack\04 WareyaOpenMWShaders''',
  '''UserInterface\InventoryExtenderRedone\InventoryExtenderRedone''',
  '''UserInterface\MagicWindowExtenderOpenMW''',
  '''UserInterface\SpellTraderOpenMW''',
  '''UserInterface\OpenMWAlchemyRedone\TPA_Alchemy_Redone''',
  '''UserInterface\QuestmanModernQuestJournalOpenMW''',
  '''UserInterface\HUDWeaponChargeForOpenMW''',
  '''UserInterface\ChocolateUI''',
  '''UserInterface\SmallSkyrimCrosshairOpenMWcompatible''',
  '''UserInterface\Enchantingiconsasyouwish\Ice\Data Files''',
  '''UserInterface\GonzosSplashScreens\00 Core''',
  '''UserInterface\GonzosSplashScreens\01 Monopteryx Creature Art''',
  '''UserInterface\GonzosSplashScreens\02 Wagner Vvardenfell Maps''',
  '''UserInterface\GonzosSplashScreens\03 Wagner Bloodmoon Maps''',
  '''UserInterface\GonzosSplashScreens\04 Wagner Tribunal Map''',
  '''UserInterface\GonzosSplashScreens\05 Tamriel Rebuilt Maps''',
  '''UserInterface\GonzosSplashScreens\06 Myrcenart Addon''',
  '''UserInterface\BigIcons\07 8X Textured''',
  '''UserInterface\VanillaStyleHDIconsforAttributesandSkills''',
  '''UserInterface\VvardenfellAnimatedMainMenu\00 Animated Main Menu''',
  '''UserInterface\OpenMWSkyrimStyleQuestNotifications''',
  '''UserInterface\SkyrimStyleQuestNotificationsLegendaryEdition\Data Files''',
  '''UserInterface\SkyrimStyleQuestNotificationsGreatPatchHub''',
  '''UserInterface\OpenMWHUDMarkersDetectspells\HUDMarkers''',
  '''Movies\HDIntroCinematicEnglish''',
  '''UserInterface\StatsWindowExtenderOpenMW''',
  '''OAABData\HD''',
  '''Cutting Room Floor - High Resolution Textures''',
  '''BeautifulCitiesofMorrowind\06 HD Textures''',
  '''OAABGrazelands\03 HD Textures''',
  '''OAABTelMora\02 HD Textures''',
  '''ByAzura\01 High Res Textures''',
  '''AlmalexiaRedone\HD''',
  '''TheMananautsMessage\03 HD Textures''',
  '''RedWisdomAnAshlanderProphecy\01 HD Textures''',
  '''SecretsoftheCrystalCity\01 HD Textures''',
  '''GreymarchDawnWhispersofJyggalag\01 HD Textures''',
  '''TheSearchfortheWhiteWave\02 HD Textures''',
  '''CalderaPrioryandtheDepthsofBloodandBone\HD''',
  '''TempleMaster\04 HD Textures''',
  '''MageRobes\04 HD Textures''',
  '''ThePopularPlague\02 HD Textures''',
  '''RemirosGroundcover\01b Thicker Grass OpenMW''',
  '''MOMWPatches\23 Little Landscapes Seyda Neen Swamp Pools Patched''',
]
removeContent = [
  '''bcomxpfp.omwaddon''',
  '''ghastly gg.esp''',
  '''Unique Banners and Signs.esp''',
  '''Unique Banners and Signs Rat in the Pot.esp''',
  '''Unique_Tavern_Signs_for_Tamriel_Rebuilt_v2.ESP''',
  '''PR Perfect Scum.esp''',
  '''Meteor.esp''',
  '''harvest-lights.omwscripts''',
  '''LeaveTheLightsOff.omwscripts''',
  '''Held Light Boost.omwscripts''',
  '''Better Skulls.ESP''',
  '''Containers Animated.esp''',
  '''The Madstone.ESP''',
  '''Dynamic Ambient Visual Effects.omwscripts''',
  '''RP_fireflies.ESP''',
  '''diverse-blood-openmw-lua.omwscripts''',
  '''Impact Effects.omwscripts''',
  '''mistify.ESP''',
  '''ReAnimation_API.omwscripts''',
  '''ReAnimation_v3.omwscripts''',
  '''third-person-alt-attacks.omwscripts''',
  '''animated-levitation.omwscripts''',
  '''footsteps.omwscripts''',
  '''OAAB - The Ashen Divide.ESP''',
  '''Valley of the Wind Overhaul.esp''',
  '''Faces of Vel - Ash Mire.ESP''',
  '''DM_RiverOfFire.ESP''',
  '''DM_SouthernAshlandsTrees.ESP''',
  '''DM_AshlandsWall.ESP''',
  '''RP_Great_Scathes.ESP''',
  '''The Mountain of Fear.ESP''',
  '''Bal'laku - The Lonely Towers.esp''',
  '''SuranBarrierRocks.ESP''',
  '''Great Seawall of Vivec.ESP''',
  '''Little Landscape Vivec Islands Plain.ESP''',
  '''Vivec_Lighthouse.ESP''',
  '''Odai River Upper Overhaul.esp''',
  '''The Grove of Ben'Abi Enhanced.ESP''',
  '''RockyAzurasCoast.ESP''',
  '''OAAB Dwemer Pavements.esm''',
  '''Trackless Grazeland OAAB Dwemer Pavements Patch.ESP''',
  '''OAAB Pomegranates.ESP''',
  '''SPT Limits.esp''',
  '''SPT Limits.omwscripts''',
  '''BestFriendsForever.omwscripts''',
  '''FriendlierFire.omwscripts''',
  '''DynamicTimescale.omwscripts''',
  '''go-home.omwscripts''',
  '''go-home-locking-doors.omwscripts''',
  '''LightHotkey.omwscripts''',
  '''shield-unequipper.omwscripts''',
  '''convenient-thief-tools.omwscripts''',
  '''NoWitnessNoBounty.omwaddon''',
  '''NoWitnessNoBounty.omwscripts''',
  '''Perfect Placement.omwscripts''',
  '''Argonian Full Helms OpenMW-Lua.omwaddon''',
  '''Boots for Beasts OpenMW Lua.omwaddon''',
  '''Boots for Beasts OpenMW Lua TD.omwaddon''',
  '''Hist Helms OpenMW Lua.omwaddon''',
  '''protected-beasts.omwscripts''',
  '''SneakIsGoodNow.omwaddon''',
  '''SneakIsGoodNow.omwscripts''',
  '''SneakFatigueDrain.omwscripts''',
  '''state-based-magicka-regen.omwscripts''',
  '''ReadingOverhaul.omwscripts''',
  '''fresh-loot.omwscripts''',
  '''fresh-loot-restoration.omwaddon''',
  '''smart-ammo.omwscripts''',
  '''BetterArmorTraining.omwscripts''',
  '''BugMuskPerfume.esp''',
  '''MDMD - More Deadly Morrowind Denizens.ESP''',
  '''mdmd - uvirith legacy cooperation.ESP''',
  '''MDMD - Creatures Add-On.ESP''',
  '''Ash Vampire Script Fix.esp''',
  '''Sixth House Rebalance.ESP''',
  '''Sunder and keening hurt on pickup.ESP''',
  '''Unused Dagoth Placement.ESP''',
  '''Tribunal Rebalance.ESP''',
  '''Bloodmoon Rebalance.ESP''',
  '''FtRP_Services.ESP''',
  '''bms.omwscripts''',
  '''Ownership Overhaul.esm''',
  '''PR Real Disposition Light.esp''',
  '''FatigueSpeedAndCarryWeightRebalance.omwaddon''',
  '''Pickpocket Rebalance.omwaddon''',
  '''Better Blight.ESP''',
  '''ExpandingBlight.omwaddon''',
  '''deadly-blight-openmw-lua.omwscripts''',
  '''Daedra Use Bound Equipment for OpenMW.omwscripts''',
  '''bound-balance.omwaddon''',
  '''bound-balance.omwscripts''',
  '''Soulless Summons.ESP''',
  '''Better Vampires.ESP''',
  '''Better Vampires TD.ESP''',
  '''Better_Vampires.omwscripts''',
  '''No more Dr Nerevarine.ESP''',
  '''MRF-AreaEffectArrows-MOMW-patch.omwaddon''',
  '''MRF-spells.omwaddon''',
  '''MRF.omwscripts''',
  '''betterpersuasionTRPT.esp''',
  '''SHOTN_BBTaP_Patch.omwaddon''',
  '''AFFresh_BBTaP_Patch.omwaddon''',
  '''BBTaP GMST Addon.omwaddon''',
  '''BBTaP.omwscripts''',
  '''sanecustompotions.omwscripts''',
  '''solSixthHouseAmulet.esp''',
  '''ngardencgdescription.omwaddon''',
  '''ngarde.omwscripts''',
  '''MoveLikeThis.omwscripts''',
  '''IronFistForOpenMW.omwscripts''',
  '''BullseyeGMSTs.omwaddon''',
  '''Bullseye.omwscripts''',
  '''ArrowStick.omwscripts''',
  '''TakeCover.omwscripts''',
  '''FairCare.omwaddon''',
  '''FairCare.omwscripts''',
  '''LuaMultiMark.omwscripts''',
  '''Reanimation Spell.omwaddon''',
  '''Reanimation Spell.omwscripts''',
  '''ncg.omwaddon''',
  '''ncg.omwscripts''',
  '''skill-evolution.omwaddon''',
  '''skill-evolution.omwscripts''',
  '''RacesRESPECted.esp''',
  '''BirthsignsRESPECted.esp''',
  '''nopopup-chargen.esp''',
  '''Fabulous-Hlaalo-Manor.ESP''',
  '''Fabulous-Hlaalo-Manor-Ralens-Clutter.ESP''',
  '''Fabulous-Hlaalo-Manor-Fabulous-Servant-Quarters.ESP''',
  '''Fabulous-Hlaalo-Manor-DOOR-HOTFIX.ESP''',
  '''The Archmagister's Abode.ESP''',
  '''Rather Nice Factor's Estate.esp''',
  '''Rather Nice Factor's Estate - GitD.esp''',
  '''RnFE - Patch for Purists.esp''',
  '''Indoril Mansion.ESP''',
  '''Nine-holes - Core.esp''',
  '''Nine-holes - Sadrith Mora, Dirty Muriel's Cornerclub.esp''',
  '''Nine-holes - Ald-ruhn, The Rat In The Pot.esp''',
  '''Nine-holes - Ebonheart, Six Fishes.esp''',
  '''Nine-holes - Moonmoth Legion Fort.esp''',
  '''Nine-holes - Pelagiad, Halfway Tavern.esp''',
  '''Nine-holes - Seyda Neen, Arrille's Tradehouse.esp''',
  '''Nine-holes - Suran, Goldyn Belaram (BCOM).esp''',
  '''Nine-holes - Vivec, Elven Nations Cornerclub.esp''',
  '''action-camera-swap.omwscripts''',
  '''Consuming Animated.omwscripts''',
  '''InventoryExtenderRedone.omwscripts''',
  '''removeSpellFix.omwaddon''',
  '''MagicWindowExtender.omwscripts''',
  '''SpellTrader.omwscripts''',
  '''TPA_Alchemy_Redone.omwscripts''',
  '''questman.omwscripts''',
  '''HUDweaponCharge.omwscripts''',
  '''SSQN.omwscripts''',
  '''HUDMarkers.omwscripts''',
  '''StatsWindow.ESP''',
  '''StatsWindow.omwscripts''',
  '''Little Landscapes - Seyda Neen Swamp Pools.ESP''',
]
'@

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
# A TES3 plugin's masters, from the MAST entries of its header record.
function Get-Masters([string]$file) {
    $masters = @()
    $stream = [IO.File]::OpenRead($file)
    try {
        $reader = New-Object IO.BinaryReader($stream)
        if ([Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) -ne "TES3") { return $masters }
        $end = 16 + $reader.ReadUInt32()
        $null = $reader.ReadBytes(8)
        while ($stream.Position + 8 -le $end) {
            $name = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
            $data = $reader.ReadBytes($reader.ReadUInt32())
            if ($name -eq "MAST") { $masters += [Text.Encoding]::GetEncoding(1252).GetString($data).TrimEnd([char]0) }
        }
    } finally { $stream.Close() }
    return $masters
}

function Write-Customizations([string[]]$pruned) {
    $text = $customizations.TrimEnd()
    if ($pruned.Count -gt 0) {
        # removeContent is the last array: the dropped plugins join it
        $text = $text.Substring(0, $text.Length - 1) + (($pruned | ForEach-Object { "  '''$_'''," }) -join "`n") + "`n]"
    }
    New-Item -ItemType Directory -Force $PcConfig | Out-Null
    [IO.File]::WriteAllText($customFile, $text + "`n")
}

$customFile = Join-Path $PcConfig "momw-customizations.toml"
$pruned = New-Object System.Collections.Generic.List[string]
if ($List -eq "expanded-vanilla") {
    Write-Customizations $pruned
    Write-Host "RG477M custom list: $customFile"

    # Patches for mods this build leaves out would stop OpenMW ("missing master"). Each round
    # lets the configurator write the load order, then drops plugins whose masters aren't in it.
    Step "Leaving out patches for mods that are not in this build"
    for ($round = 1; $round -le 6; $round++) {
        $roundStart = Get-Date
        & $configurator.FullName config $List
        $pcCfgItem = Get-Item (Join-Path $PcConfig "openmw.cfg") -ErrorAction SilentlyContinue
        if (-not $pcCfgItem -or $pcCfgItem.LastWriteTime -lt $roundStart) { Fail "momw-configurator wrote no load order ($LASTEXITCODE)." }

        $dataDirs = New-Object System.Collections.Generic.List[string]
        $plugins = New-Object System.Collections.Generic.List[string]
        foreach ($raw in Get-Content $pcCfgItem.FullName) {
            $line = $raw.Trim()
            if ($line -like "data=*") { $dataDirs.Add($line.Substring(5).Trim('"').Replace('&&', '&')) }
            elseif ($line -like "content=*") { $plugins.Add($line.Substring(8)) }
            elseif ($line -like "groundcover=*") { $plugins.Add($line.Substring(12)) }
        }
        $loaded = @{}
        foreach ($plugin in $plugins) { $loaded[$plugin.ToLower()] = $true }

        $orphans = New-Object System.Collections.Generic.List[string]
        foreach ($plugin in $plugins) {
            if ($plugin -notmatch '\.(esm|esp|omwaddon|omwgame)$') { continue }
            $file = $null
            for ($i = $dataDirs.Count - 1; $i -ge 0 -and -not $file; $i--) {
                $candidate = Join-Path $dataDirs[$i] $plugin
                if (Test-Path -LiteralPath $candidate) { $file = $candidate }
            }
            if (-not $file) { continue }
            foreach ($master in Get-Masters $file) {
                if (-not $loaded.ContainsKey($master.ToLower())) {
                    Write-Host "  $plugin (needs $master)"
                    $orphans.Add($plugin)
                    break
                }
            }
        }
        if ($orphans.Count -eq 0) { break }
        $pruned.AddRange($orphans)
        Write-Customizations $pruned
    }
    Write-Host "$($pruned.Count) patches left out."
}
$configStart = Get-Date
& $configurator.FullName config --verbose --run-navmeshtool --run-validator $List
if ($LASTEXITCODE -ne 0) {
    $pcCfgFile = Get-Item (Join-Path $PcConfig "openmw.cfg") -ErrorAction SilentlyContinue
    $validatorLog = Get-ChildItem $PcConfig -Filter "validator-*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime | Select-Object -Last 1
    if ($validatorLog) { Copy-Item $validatorLog.FullName (Join-Path $Momw "validator.log") -Force }
    if ($pcCfgFile -and $pcCfgFile.LastWriteTime -gt $configStart) {
        # the load order and navmesh are written before the validator runs; a mod that renamed
        # a folder since the list was written trips it, and the conversion below finds those
        Write-Host "The validator found problems (momw\validator.log); the checks below repair what they can." -ForegroundColor Yellow
    } else {
        Write-Host "momw-configurator stopped ($LASTEXITCODE)." -ForegroundColor Yellow
        if (-not (Ask "Try again without the navmesh step?")) { exit 1 }
        & $configurator.FullName config --verbose --run-validator $List
        if ($LASTEXITCODE -ne 0 -and -not ((Get-Item (Join-Path $PcConfig "openmw.cfg") -ErrorAction SilentlyContinue).LastWriteTime -gt $configStart)) {
            Fail "momw-configurator failed ($LASTEXITCODE)."
        }
    }
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

# A mod updated after the list was written may have renumbered a folder ("01 Patch" is now
# "04 Patch"): the folder next to it with the same name after the number is the one.
function Find-Renamed([string]$path) {
    $parent = Split-Path $path -Parent
    if (-not (Test-Path -LiteralPath $parent)) { return $null }
    $name = (Split-Path $path -Leaf) -replace '^\d+\s+', ''
    $same = @(Get-ChildItem -LiteralPath $parent -Directory | Where-Object { ($_.Name -replace '^\d+\s+', '') -ieq $name })
    if ($same.Count -eq 1) { return $same[0].FullName }
    return $null
}
$renamedNotes = New-Object System.Collections.Generic.List[string]

# menu and intro video replacers: their Bink videos don't play in OpenMW for Android
$leftOut = @("00 Animated Main Menu", "HDIntroCinematicEnglish")

foreach ($raw in Get-Content $pcCfg) {
    $line = $raw.Trim()
    if ($line -notmatch '^(data|content|groundcover|fallback-archive)\s*=\s*(.*)$') { continue }
    $key = $Matches[1]; $value = $Matches[2].Trim()
    if ($key -eq "data") {
        $path = $value.Trim('"').Replace('&&', '&')
        if ($leftOut -contains (Split-Path $path -Leaf)) { Write-Host "  left out $path"; continue }
        if (-not (Test-Path -LiteralPath $path)) {
            $renamedTo = Find-Renamed $path
            if (-not $renamedTo) { $problems.Add("missing mod folder: $path"); continue }
            $renamedNotes.Add("renamed by its mod: $path -> $renamedTo")
            Write-Host "  $path is now $renamedTo"
            $path = $renamedTo
        }
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
if ($renamedNotes.Count -gt 0) { $report = $renamedNotes + @("") + $report }
if ($problems.Count -gt 0) { $report = @("PROBLEMS:") + $problems + @("") + $report }
[IO.File]::WriteAllLines((Join-Path $Momw "check.txt"), $report)
if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "Run this script again to resume umo; the list in momw\check.txt" -ForegroundColor Red
} else {
    Write-Host "All folders and plugins present, in the configurator's order (momw\check.txt)." -ForegroundColor Green
}

# ---------------------------------------------------------------------------- RG477M additions

# Patches you downloaded yourself: each folder in C:\Morrowind477M\Extra is copied into
# OpenMWMods and loaded after the list, plugins in name order.
$extraSource = Join-Path $Work "Extra"
if (Test-Path $extraSource) {
    foreach ($folder in Get-ChildItem $extraSource -Directory | Sort-Object Name) {
        Step "Adding $($folder.Name) from Extra"
        $target = Join-Path $Mods $folder.Name
        robocopy $folder.FullName $target /E /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { Fail "Copying $($folder.Name) failed." }
        $lines.Add('data="' + (To-Android $target) + '"')
        foreach ($plugin in Get-ChildItem $target -File | Where-Object { $_.Extension -match '^\.(esm|esp|omwaddon|omwscripts)$' } | Sort-Object Name) {
            $lines.Add("content=$($plugin.Name)")
            Write-Host "  $($plugin.Name)"
        }
    }
    [IO.File]::WriteAllLines((Join-Path $Momw "openmw.cfg"), $lines)
}

if (-not $KeepStartingSkills) {
    Step "Adding Skills Start At One"
    # mods/SkillsStartAtOne in GammaOSNext; last in the load order so nothing resets it
    $skillsMod = Join-Path $Mods "SkillsStartAtOne"
    New-Item -ItemType Directory -Force (Join-Path $skillsMod "scripts\SkillsStartAtOne") | Out-Null
    [IO.File]::WriteAllText((Join-Path $skillsMod "SkillsStartAtOne.omwscripts"), "PLAYER: scripts/SkillsStartAtOne/player.lua`n")
    [IO.File]::WriteAllText((Join-Path $skillsMod "scripts\SkillsStartAtOne\player.lua"), @'
-- Skills Start At One (RG477M), for OpenMW 0.49 and newer.
--
-- A new character's skills are all set to one level (1 by default) the moment character
-- creation ends: when you walk out of the Census and Excise Office with your class and
-- birthsign. Characters that were past character creation before the mod was added keep
-- their skills, unless you use "Set this character's skills now" in
-- Options > Scripts > Skills Start At One.
--
-- Leveling mods (Natural Character Growth, Skill Evolution) set up their own state when
-- character creation ends, so the level is held for a few seconds to have the last word.

local async = require('openmw.async')
local core = require('openmw.core')
local I = require('openmw.interfaces')
local self = require('openmw.self')
local storage = require('openmw.storage')
local types = require('openmw.types')
local ui = require('openmw.ui')

local GROUP = 'SettingsSkillsStartAtOne'
local HOLD_SECONDS = 5
local CENSUS_OFFICE = 'seyda neen, census and excise office'

I.Settings.registerPage {
    key = 'SkillsStartAtOne',
    l10n = 'SkillsStartAtOne',
    name = 'Skills Start At One',
    description = 'pageDescription',
}
I.Settings.registerGroup {
    key = GROUP,
    page = 'SkillsStartAtOne',
    l10n = 'SkillsStartAtOne',
    name = 'Skills Start At One',
    permanentStorage = true,
    settings = {
        {
            key = 'level',
            renderer = 'number',
            name = 'levelName',
            description = 'levelDescription',
            default = 1,
            argument = { integer = true, min = 0, max = 100 },
        },
        {
            key = 'applyNow',
            renderer = 'checkbox',
            name = 'applyNowName',
            description = 'applyNowDescription',
            default = false,
        },
    },
}
local settings = storage.playerSection(GROUP)

-- 'waiting': in character creation; 'done': this character has had its skills set, or was
-- already past character creation when the mod arrived
local phase = nil
local holdUntil = 0
local lastCell = nil

local function setSkills()
    local level = settings:get('level') or 1
    for _, skill in ipairs(core.stats.Skill.records) do
        local accessor = types.NPC.stats.skills[skill.id]
        if accessor then
            local stat = accessor(self)
            if stat.base ~= level then
                stat.base = level
            end
            stat.progress = 0
        end
    end
end

local function start(message)
    phase = 'done'
    local ok, err = pcall(setSkills)
    if not ok then
        ui.showMessage('Skills Start At One failed: ' .. tostring(err))
        return
    end
    holdUntil = core.getRealTime() + HOLD_SECONDS
    ui.showMessage(message:format(settings:get('level') or 1))
end

settings:subscribe(async:callback(function(_, key)
    if key == 'applyNow' and settings:get('applyNow') then
        settings:set('applyNow', false)
        start('Every skill set to %d.')
    end
end))

local function firstLook()
    phase = types.Player.isCharGenFinished(self) and 'done' or 'waiting'
end

return {
    engineHandlers = {
        onInit = firstLook,
        onUpdate = function()
            if phase == nil then
                firstLook()
            end
            local cell = self.cell and self.cell.name:lower() or nil
            if phase == 'waiting' then
                local leftOffice = lastCell == CENSUS_OFFICE and cell ~= CENSUS_OFFICE
                if types.Player.isCharGenFinished(self) or leftOffice then
                    start('Every skill starts at %d.')
                end
            elseif core.getRealTime() < holdUntil then
                pcall(setSkills)
            end
            lastCell = cell
        end,
        onSave = function()
            return { phase = phase }
        end,
        onLoad = function(data)
            phase = data and data.phase or nil
        end,
    },
}
'@)
    New-Item -ItemType Directory -Force (Join-Path $skillsMod "l10n\SkillsStartAtOne") | Out-Null
    [IO.File]::WriteAllText((Join-Path $skillsMod "l10n\SkillsStartAtOne\en.yaml"), @'
pageDescription: "Every skill of a new character starts at one level once character creation ends (leaving the Census and Excise Office)."
levelName: "Starting skill level"
levelDescription: "The level every skill is set to. 1 by default."
applyNowName: "Set this character's skills now"
applyNowDescription: "Sets every skill of the character you are playing to the starting level, once."
'@)
    $lines.Add('data="' + (To-Android $skillsMod) + '"')
    $lines.Add("content=SkillsStartAtOne.omwscripts")
    [IO.File]::WriteAllLines((Join-Path $Momw "openmw.cfg"), $lines)
    Write-Host "New characters get every skill at 1 after character creation (-KeepStartingSkills leaves it out)."
}

# ---------------------------------------------------------------------------- handheld textures

Step "Shrinking textures over 1024 pixels"
$lowRes = @($PSScriptRoot, $Work) | ForEach-Object { Join-Path $_ "RG477M-Morrowind-LowRes.ps1" } |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if ($lowRes) {
    & $lowRes -Work $Work -NoZip
} else {
    Write-Host "RG477M-Morrowind-LowRes.ps1 is not in $Work; textures stay full size." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------- done

$sizeGb = [math]::Round(((Get-ChildItem $Out -Recurse -File | Measure-Object Length -Sum).Sum) / 1GB, 1)
Step "Ready: $Out ($sizeGb GB)"
Write-Host "Copy the whole 'Morrowind Android' folder to the RG477M's Internal storage\Documents"
Write-Host "(a USB cable to the PC is the fastest way). Then start OpenMW Mali Mobile."
Step "Zipping (a while for $sizeGb GB)"
$zipFile = Join-Path $Work "Morrowind Android.zip"
Remove-Item -LiteralPath $zipFile -ErrorAction SilentlyContinue
tar.exe -a -c -f $zipFile -C $Work "Morrowind Android"
if ($LASTEXITCODE -ne 0) { Fail "Making the zip failed ($LASTEXITCODE)." }
Write-Host "Zip: $zipFile. Unzip it into Internal storage\Documents on the RG477M."
Write-Host "The download cache $Cache can be deleted now."
