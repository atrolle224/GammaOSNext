#!/usr/bin/env python3
"""Daijishou platform files for the RG477M, to import without root.

usage: build.py <Daijishou platforms dir> <out dir>

<Daijishou platforms dir> is platforms/ of github.com/TapiocaFox/Daijishou. Each platform the
setup covers is written to <out>/Platforms with the 477M apps first in its player list (first
is Daijishou's default), followed by the official players. The ports get platforms of their
own, one placeholder file each in <out>/SD card/ROMs/<Port>.
"""
import copy
import json
import os
import sys

src, out = sys.argv[1:]
platforms_out = os.path.join(out, "Platforms")
roms_out = os.path.join(out, "SD card", "ROMs")
os.makedirs(platforms_out, exist_ok=True)

RA = "com.retroarch.rg477m"
RA_CFG = "/storage/emulated/0/RetroArch/retroarch.cfg"


def retroarch(short, core, label, regex=None):
    """RetroArch 477M with <core>, from the official RetroArch (aarch64) player for it (or <regex>
    when Daijishou has none)."""
    return ("ra", short, core, label, regex)


# platform file: (ROM folder, [players]); a player is (unique id, name, description, am start
# arguments, filename regex or None to take the official player's) or a retroarch() rule
DOLPHIN_MMJR2 = ("org.dolphinemu.mmjr.rg477m", "Dolphin MMJR2 477M",
                 "Dolphin MMJR2 with the RG477M defaults; PSO Episode I & II starts on SCHTSERV.")
DOLPHIN_477M = ("org.dolphinemu.dolphinemu.rg477m", "Dolphin 477M",
                "Dolphin 477M: RetroAchievements, RG477M defaults, PSO on SCHTSERV.")
PRIMEHACK_477M = ("org.dolphinemu.primehack.rg477m", "PrimeHack 477M",
                  "PrimeHack 477M: Metroid Prime 1-3 and Trilogy with right-stick aiming.")


def dolphin(short):
    regex = r"^(.*)\.(?:iso|gcm|ciso|gcz|rvz|wbfs|wad|dol|elf|tgc|wia|nfs|m3u)$"
    return [
        (f"{short}.rg477m.mmjr2", f"{short} - {DOLPHIN_MMJR2[1]}", DOLPHIN_MMJR2[2],
         f"-n {DOLPHIN_MMJR2[0]}/org.dolphinemu.dolphinemu.ui.main.MainActivity\n"
         " -a android.intent.action.MAIN\n -e AutoStartFile {file.path}", regex),
        (f"{short}.rg477m.dolphin", f"{short} - {DOLPHIN_477M[1]}", DOLPHIN_477M[2],
         f"-n {DOLPHIN_477M[0]}/org.dolphinemu.dolphinemu.ui.main.MainActivity\n"
         " -a android.intent.action.MAIN\n -e AutoStartFile {file.uri}", regex),
        (f"{short}.rg477m.primehack", f"{short} - {PRIMEHACK_477M[1]}", PRIMEHACK_477M[2],
         f"-n {PRIMEHACK_477M[0]}/org.dolphinemu.dolphinemu.ui.main.MainActivity\n"
         " -a android.intent.action.MAIN\n -e AutoStartFile {file.uri}", regex),
    ]


DOS_REGEX = r"^(.*)\.(?:zip|dosz|dosc|conf|exe|com|bat|iso|cue|img|ima|vhd|m3u|m3u8)$"

SETUP = {
    # found by its short name, as the file's name may change between Daijishou versions
    "shortname:dos": ("dos", [
        retroarch("dos", "dosbox_pure", "DOSBox Pure", DOS_REGEX),
        # DOSBox Turbo starts no game from outside: it opens, the game runs from its own setup
        ("dos.rg477m.dosboxturbo", "dos - DOSBox Turbo",
         "DOSBox Turbo (com.fishstix.dosbox): opens DOSBox Turbo; start the game from its own profile.",
         "-n com.fishstix.dosbox/com.fishstix.dosbox.DBMain\n -a android.intent.action.VIEW\n -d {file.uri}",
         DOS_REGEX)]),
    "NintendoGameBoy.json": ("gb", [retroarch("gb", "gambatte", "gambatte")]),
    "NintendoGameBoyColor.json": ("gbc", [retroarch("gbc", "gambatte", "gambatte")]),
    "NintendoGameBoyAdvance.json": ("gba", [retroarch("gba", "mgba", "mGBA")]),
    "NintendoEntertainmentSystem.json": ("nes", [retroarch("nes", "fceumm", "FCEUmm")]),
    "NintendoSNES.json": ("snes", [
        ("snes.rg477m.snes9xex", "snes - Snes9x EX+ 477M",
         "Snes9x EX+ 477M: left stick as D-pad, R3 menu, L3 system actions (com.explusalpha.Snes9xPlus.rg477m).",
         "-n com.explusalpha.Snes9xPlus.rg477m/com.imagine.BaseActivity\n -a android.intent.action.VIEW\n -d {file.uri}", None),
        retroarch("snes", "snes9x", "Snes9x")]),
    "SegaMasterSystem.json": ("master", [retroarch("master", "genesis_plus_gx", "Genesis Plus GX")]),
    "SegaGenesis.json": ("genesis", [retroarch("genesis", "genesis_plus_gx", "Genesis Plus GX")]),
    "SegaGameGear.json": ("gamegear", [retroarch("gamegear", "genesis_plus_gx", "Genesis Plus GX")]),
    "SegaCD.json": ("segacd", [retroarch("segacd", "genesis_plus_gx", "Genesis Plus GX")]),
    "NeoGeoPocketColor.json": ("ngpc", [retroarch("ngpc", "mednafen_ngp", "Beetle NeoPop")]),
    "SonyPlayStation.json": ("psx", [retroarch("psx", "swanstation", "SwanStation"),
                                     retroarch("psx", "pcsx_rearmed", "PCSX ReARMed")]),
    "Nintendo64.json": ("n64", [
        # RetroAchievements: RetroArch's Mupen64Plus-Next (the Android core is its GLES3 build)
        retroarch("n64", "mupen64plus_next_gles3", "Mupen64Plus-Next",
                  r"^(.*)\.(?:n64|v64|z64|ndd|u1|bin|zip|7z)$"),
        ("n64.rg477m.m64plusfz", "n64 - M64Plus FZ 477M", "M64Plus FZ 477M (org.mupen64plusae.v3.fzurita.rg477m).",
         "-n org.mupen64plusae.v3.fzurita.rg477m/paulscode.android.mupen64plusae.SplashActivity\n"
         " -a android.intent.action.VIEW\n -d {file.uri}", None)]),
    "NintendoDS.json": ("nds", [
        ("nds.rg477m.melonds", "nds - melonDS 477M", "melonDS 477M (me.magnum.melonds.rg477m).",
         "-n me.magnum.melonds.rg477m/me.magnum.melonds.ui.emulator.EmulatorActivity\n"
         " -a me.magnum.melonds.rg477m.LAUNCH_ROM\n -e uri {file.uri}", None)]),
    "NintendoGameCube.json": ("gc", dolphin("gc")),
    "NintendoWii.json": ("wii", dolphin("wii")),
    "SegaDreamcast.json": ("dreamcast", [
        ("dreamcast.rg477m.flycast", "dreamcast - Flycast 477M", "Flycast 477M (com.flycast.emulator.rg477m).",
         "-n com.flycast.emulator.rg477m/com.flycast.emulator.MainActivity\n"
         " -a android.intent.action.VIEW\n -d {file.uri}", None)]),
    # your own copy of Saturn.emu, already in Daijishou's list
    "SegaSaturn.json": ("saturn", [("official", "saturn.com.explusalpha.SaturnEmu")]),
    "SonyPSP.json": ("psp", [
        ("psp.rg477m.ppsspp", "psp - PPSSPP 477M", "PPSSPP 477M (org.ppsspp.ppsspp.rg477m).",
         "-n org.ppsspp.ppsspp.rg477m/org.ppsspp.ppsspp.PpssppActivity\n"
         " -a android.intent.action.VIEW\n -c android.intent.category.DEFAULT\n -d {file.uri}\n"
         " -t application/octet-stream\n --activity-clear-task\n --activity-clear-top\n --activity-no-history",
         None)]),
    "SonyPlayStation2.json": ("ps2", [
        ("ps2.rg477m.armsx2.net", "ps2 - ARMSX2 Net 477M", "ARMSX2 with the latest upstream changes (com.armsx2.netmod).",
         "-n com.armsx2.netmod/com.armsx2.Main\n -a android.intent.action.VIEW\n -d {file.uri}", None),
        ("ps2.rg477m.armsx2.dns", "ps2 - ARMSX2 DNS 477M", "The EQOA build (com.armsx2.dnsmod).",
         "-n com.armsx2.dnsmod/com.armsx2.Main\n -a android.intent.action.VIEW\n -d {file.uri}", None)]),
    "MicrosoftXbox.json": ("xbox", [
        ("xbox.rg477m.hakux", "xbox - hakuX 477M", "hakuX with the RG477M Mali work (com.rfandango.haku_x.debug).",
         "-n com.rfandango.haku_x.debug/com.rfandango.haku_x.LauncherActivity\n -d {file.uri}", None)]),
}

# (folder and placeholder name, platform name, unique id, package/activity, extra arguments, description)
PORTS = [
    # (ROMs folder, platform name, id, launch component, extra args, description, game entry's name)
    ("fallout", "Fallout", "fallout477m", "com.alexbatalov.falloutce.rg477m/com.alexbatalov.falloutce.MainActivity", "",
     "Fallout Community Edition 477M, with your Steam/GOG game files.", "Fallout"),
    ("fallout2", "Fallout 2", "fallout2477m", "com.alexbatalov.fallout2ce.rg477m/com.alexbatalov.fallout2ce.MainActivity", "",
     "Fallout 2 Community Edition 477M, with your Steam/GOG game files.", "Fallout 2"),
    ("perfectdark", "Perfect Dark", "perfectdark477m", "com.perfectdark.port.rg477m/com.perfectdark.port.LauncherActivity", "",
     "The Perfect Dark port; pick your N64 ROM in its launcher once.", "Perfect Dark"),
    ("morrowind", "The Elder Scrolls III: Morrowind", "openmw477m", "com.ast.openmw.rg477m/ui.activity.MainActivity",
     "\n --ez rg477m.autostart true", "OpenMW Mali Mobile with the mod list from RG477M-Morrowind.ps1; starts the game directly.",
     "Morrowind"),
    ("ultimaonline", "Ultima Online (UOAlive)", "ultimaonline477m", "com.mobileuo.mobileuo.rg477m/com.unity3d.player.UnityPlayerActivity", "",
     "MobileUO 477M set up for UOAlive, with controller play.", "Ultima Online"),
    ("runescape", "Old School RuneScape", "osrs477m", "com.rg477m.osrspad/com.rg477m.osrspad.PlayActivity", "",
     "The official Old School RuneScape app, opened through OSRS Pad 477M for controller play.", "Old School RuneScape"),
    ("eqoa", "EverQuest Online Adventures", "eqoa477m",
     "io.github.atrolle224.eqoa477m/io.github.dabdavis.eqoa.EqoaActivity", "",
     "EQOA 477M, the native EQOA client; Sandstorm by default, the server picked in Network Setup's Preset row. "
     "Pick your Frontiers disc image in it once.", "EverQuest Online Adventures"),
]
PORT_REGEX = r"^(.*)\.(?:port)$"


def player(uid, name, desc, args, regex):
    return {"name": name, "uniqueId": uid, "description": desc, "acceptedFilenameRegex": regex,
            "amStartArguments": args, "killPackageProcesses": True,
            "killPackageProcessesWarning": False, "extra": ""}


def ra_player(official, short, core, label, regex=None):
    base = next((p for p in official if p["uniqueId"] == f"{short}.ra64.{core}"), None)
    if base is None and regex:
        base = {"acceptedFilenameRegex": regex}
    if base is None:
        sys.exit(f"{short}: no official player {short}.ra64.{core} to start from")
    args = (f"-n {RA}/com.retroarch.browser.retroactivity.RetroActivityFuture\n -e ROM {{file.path}}\n"
            f" -e LIBRETRO /data/data/{RA}/cores/{core}_libretro_android.so\n -e CONFIGFILE {RA_CFG}")
    return player(f"{short}.rg477m.ra.{core}", f"{short} - RetroArch 477M ({label})",
                  f"RetroArch 477M with {label}: RetroAchievements on, controllers set up for the RG477M.",
                  args, base["acceptedFilenameRegex"])


def by_shortname(short):
    for fname in sorted(os.listdir(src)):
        if fname.endswith(".json"):
            with open(os.path.join(src, fname), encoding="utf-8") as f:
                if json.load(f).get("platform", {}).get("shortname") == short:
                    return fname
    sys.exit(f"no Daijishou platform with the short name {short}")


SETUP = {(by_shortname(k[10:]) if k.startswith("shortname:") else k): v for k, v in SETUP.items()}

written = []
for name, (folder, rules) in SETUP.items():
    with open(os.path.join(src, name), encoding="utf-8") as f:
        data = json.load(f)
    official = data["playerList"]
    ours = []
    for rule in rules:
        if rule[0] == "ra":
            ours.append(ra_player(official, *rule[1:]))
        elif rule[0] == "official":
            found = next((p for p in official if p["uniqueId"] == rule[1]), None)
            if found is None:
                sys.exit(f"{name}: no official player {rule[1]}")
            ours.append(found)
        else:
            uid, pname, desc, args, regex = rule
            regex = regex or (official[0]["acceptedFilenameRegex"] if official else r"^(.*)\..*$")
            ours.append(player(uid, pname, desc, args, regex))
    ids = {p["uniqueId"] for p in ours}
    data["playerList"] = ours + [p for p in official if p["uniqueId"] not in ids]
    data["revisionNumber"] = data.get("revisionNumber", 0) + 1000
    data["platform"]["description"] = (f"RG477M: put these games in ROMs/{folder} on the SD card. "
                                       + (data["platform"].get("description") or ""))
    with open(os.path.join(platforms_out, name), "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    os.makedirs(os.path.join(roms_out, folder), exist_ok=True)
    written.append((name, folder, data["playerList"][0]["name"]))

for folder, title, uid, component, extra, desc, game in PORTS:
    data = {
        "databaseVersion": 14,
        "revisionNumber": 2,
        "platform": {
            "name": title, "uniqueId": uid, "shortname": uid,
            "description": f"{desc} Point this platform at ROMs/{folder}, which holds {game}.port.",
            "acceptedFilenameRegex": PORT_REGEX,
            "scraperSourceList": [], "boxArtAspectRatioId": 1, "useCustomBoxArtAspectRatio": False,
            "customBoxArtAspectRatio": None, "screenAspectRatioId": 1, "useCustomScreenAspectRatio": False,
            "customScreenAspectRatio": None, "retroAchievementsConsoleIdList": [], "extra": "",
        },
        "playerList": [player(f"{uid}.play", f"{uid} - {title}", desc, f"-n {component}{extra}\n --activity-clear-task",
                              PORT_REGEX)],
    }
    if component.startswith("com.rg477m.osrspad/"):
        # killing the package would stop the controller service it hosts
        data["playerList"][0]["killPackageProcesses"] = False
    fname = "Port - " + title.replace(":", "") + ".json"
    with open(os.path.join(platforms_out, fname), "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    d = os.path.join(roms_out, folder)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, game + ".port"), "w") as f:
        f.write(f"Daijishou launches {title} from this file; leave it here.\n")
    written.append((fname, folder, data["playerList"][0]["name"]))

# Windows 98 in DOSBox Pure: its own folder, so RetroArch loads config/DOSBox-pure/win98.opt
# (a content directory's core options) for the games in it
win98 = ra_player([], "win98", "dosbox_pure", "DOSBox Pure", DOS_REGEX)
data = {
    "databaseVersion": 14,
    "revisionNumber": 1,
    "platform": {
        "name": "Windows 98", "uniqueId": "win98.rg477m", "shortname": "win98",
        "description": ("Windows 95/98 games in DOSBox Pure with a Windows 98 installed once. Put your "
                        "Windows 98 CD image and the games' CD images or zips in ROMs/win98."),
        "acceptedFilenameRegex": DOS_REGEX,
        "scraperSourceList": [], "boxArtAspectRatioId": 1, "useCustomBoxArtAspectRatio": False,
        "customBoxArtAspectRatio": None, "screenAspectRatioId": 1, "useCustomScreenAspectRatio": False,
        "customScreenAspectRatio": None, "retroAchievementsConsoleIdList": [], "extra": "",
    },
    "playerList": [win98],
}
with open(os.path.join(platforms_out, "Windows 98.json"), "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
os.makedirs(os.path.join(roms_out, "win98"), exist_ok=True)
written.append(("Windows 98.json", "win98", win98["name"]))

for name, folder, first in written:
    print(f"{name:42} ROMs/{folder:22} default: {first}")
