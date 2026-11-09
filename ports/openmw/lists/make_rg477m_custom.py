#!/usr/bin/env python3
"""The RG477M custom list: Expanded Vanilla's content categories with what they need.

usage: make_rg477m_custom.py <expanded-vanilla api json> <out toml>

The json is modding-openmw.com/api/lists/expanded-vanilla (the MOMW list data workflow).
Writes a momw-customizations.toml that removes every other mod's folders and plugins;
the PC script then also drops plugins whose masters went with them.
"""
import json
import sys

# chosen: content
KEEP = {
    "Landmasses", "NewItems", "Groundcover", "CitiesTowns", "NPCs", "Dialogue", "Creatures",
    "CreatureVisuals", "Quests", "GuildsFactions", "DistantDetails",
    # what that content needs or plays better with
    "FirstSteps", "OfficialPlugins", "PatchesFixesandConsistency", "ModdingResources",
    "CutContent", "MeshReplacers", "ModPatches", "Tools",
    # suggested: indoor content and music cost little while playing
    "CavesandDungeons", "Interiors", "Randomizers", "Music",
}

# suggested from categories otherwise left out: small outdoor additions (big regional overhauls
# would slow the open world), homes, sounds and controller-friendly conveniences
KEEP_MODS = {
    "Uvirith's Legacy", "Building Up Uvirith's Legacy", "Draggle-Tail Shack", "The Popular Plague",
    "Little Landscapes - Bitter Coast Waterway", "Little Landscapes - Path to Pelagiad",
    "Little Landscapes - Path to Vivec Lighthouse", "Little Landscape - Path to Balmora",
    "Little Landscape - Foyada of Sharp Teeth", "OAAB Shipwrecks", "Hidden Sea Loot",
    "Justice for Khartag (J.F.K.)", "Holamayan Island", "Telvanni Sea Beacons", "Sanctus Shrine",
    "Strider Burial", "Immersive Grotto Entrances", "OAAB - Foyada Mamaea", "Gates of Ascadia",
    "Store Entrance Chimes", "Store Entrance Chimes for Cyrodiil and TR Mainland", "MAO Spell Sounds",
    "Friendly Autosave", "Graphic Herbalism - MWSE and OpenMW Edition", "Expansions Integrated",
    "Clear Your Name", "Improved Inns Expanded", "Wares Ultimate", "Signpost Fast Travel",
}

# kept mods, but not on the handheld
DROP_PATHS = [
    "OAABData/HD",
    "Cutting Room Floor - High Resolution Textures",
    "BeautifulCitiesofMorrowind/06 HD Textures",
    "OAABGrazelands/03 HD Textures",
    "OAABTelMora/02 HD Textures",
    "ByAzura/01 High Res Textures",
    "AlmalexiaRedone/HD",
    "TheMananautsMessage/03 HD Textures",
    "RedWisdomAnAshlanderProphecy/01 HD Textures",
    "SecretsoftheCrystalCity/01 HD Textures",
    "GreymarchDawnWhispersofJyggalag/01 HD Textures",
    "TheSearchfortheWhiteWave/02 HD Textures",
    "CalderaPrioryandtheDepthsofBloodandBone/HD",
    "TempleMaster/04 HD Textures",
    "MageRobes/04 HD Textures",
    "ThePopularPlague/02 HD Textures",
    "RemirosGroundcover/01b Thicker Grass OpenMW",
    "MOMWPatches/23 Little Landscapes Seyda Neen Swamp Pools Patched",
]
DROP_PLUGINS = ["Little Landscapes - Seyda Neen Swamp Pools.ESP"]

def kept(m):
    return m["category"] in KEEP or m["name"] in KEEP_MODS


def toml_list(items):
    # multi-line literal strings, because names like Ald'Ruhn hold single quotes
    quote = "'''"
    return "\n".join(f"  {quote}{i.replace('/', chr(92))}{quote}," for i in items)


def main():
    mods = json.load(open(sys.argv[1], encoding="utf-8"))
    missing = KEEP_MODS - {m["name"] for m in mods}
    if missing:
        sys.exit(f"not on the list: {sorted(missing)}")

    kept_paths = [f"{m['category']}/{p}" for m in mods if kept(m) for p in m["data_paths"]]
    kept_plugins = {p.lower() for m in mods if kept(m) for p in m["plugins"]}

    remove_paths, remove_plugins = [], []
    for m in mods:
        if kept(m):
            continue
        for p in m["data_paths"]:
            path = f"{m['category']}/{p}"
            # removeData matches by substring: never let it catch a kept folder
            if any(path in k for k in kept_paths):
                sys.exit(f"{path} would also remove a kept folder")
            remove_paths.append(path)
        remove_plugins += [p for p in m["plugins"] if p.lower() not in kept_plugins]
    remove_paths += DROP_PATHS
    remove_plugins += DROP_PLUGINS

    with open(sys.argv[2], "w", encoding="utf-8", newline="\n") as f:
        f.write("[[Customizations]]\nlistName = 'expanded-vanilla'\n")
        f.write(f"removeData = [\n{toml_list(remove_paths)}\n]\n")
        f.write(f"removeContent = [\n{toml_list(remove_plugins)}\n]\n")

    kept_mods = [m for m in mods if kept(m)]
    print(f"{len(kept_mods)} mods kept, {len(mods) - len(kept_mods)} removed: "
          f"{len(remove_paths)} folders, {len(remove_plugins)} plugins")


if __name__ == "__main__":
    main()
