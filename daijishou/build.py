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


def retroarch(short, core, label):
    """RetroArch 477M with <core>, from the official RetroArch (aarch64) player for it."""
    return ("ra", short, core, label)


# platform file: (ROM folder, [players]); a player is (unique id, name, description, am start
# arguments, filename regex or None to take the official player's) or a retroarch() rule
DOLPHIN_MMJR2 = ("org.dolphinemu.mmjr.rg477m", "Dolphin MMJR2 477M",
                 "Dolphin MMJR2 with the RG477M defaults; PSO Episode I & II starts on SCHTSERV.")
DOLPHIN_477M = ("org.dolphinemu.dolphinemu.rg477m", "Dolphin 477M",
                "Dolphin 477M: RetroAchievements, RG477M defaults, PSO on SCHTSERV.")


def dolphin(short):
    regex = r"^(.*)\.(?:iso|gcm|ciso|gcz|rvz|wbfs|wad|dol|elf|tgc|wia|nfs|m3u)$"
    return [
        (f"{short}.rg477m.mmjr2", f"{short} - {DOLPHIN_MMJR2[1]}", DOLPHIN_MMJR2[2],
         f"-n {DOLPHIN_MMJR2[0]}/org.dolphinemu.dolphinemu.ui.main.MainActivity\n"
         " -a android.intent.action.MAIN\n -e AutoStartFile {file.path}", regex),
        (f"{short}.rg477m.dolphin", f"{short} - {DOLPHIN_477M[1]}", DOLPHIN_477M[2],
         f"-n {DOLPHIN_477M[0]}/org.dolphinemu.dolphinemu.ui.main.MainActivity\n"
         " -a android.intent.action.MAIN\n -e AutoStartFile {file.uri}", regex),
    ]


SETUP = {
    "NintendoGameBoy.json": ("gb", [retroarch("gb", "gambatte", "gambatte")]),
    "NintendoGameBoyColor.json": ("gbc", [retroarch("gbc", "gambatte", "gambatte")]),
    "NintendoGameBoyAdvance.json": ("gba", [retroarch("gba", "mgba", "mGBA")]),
    "NintendoEntertainmentSystem.json": ("nes", [retroarch("nes", "fceumm", "FCEUmm")]),
    "NintendoSNES.json": ("snes", [retroarch("snes", "snes9x", "Snes9x")]),
    "SegaMasterSystem.json": ("master", [retroarch("master", "genesis_plus_gx", "Genesis Plus GX")]),
    "SegaGenesis.json": ("genesis", [retroarch("genesis", "genesis_plus_gx", "Genesis Plus GX")]),
    "SegaGameGear.json": ("gamegear", [retroarch("gamegear", "genesis_plus_gx", "Genesis Plus GX")]),
    "SegaCD.json": ("segacd", [retroarch("segacd", "genesis_plus_gx", "Genesis Plus GX")]),
    "NeoGeoPocketColor.json": ("ngpc", [retroarch("ngpc", "mednafen_ngp", "Beetle NeoPop")]),
    "SonyPlayStation.json": ("psx", [retroarch("psx", "swanstation", "SwanStation"),
                                     retroarch("psx", "pcsx_rearmed", "PCSX ReARMed")]),
    "Nintendo64.json": ("n64", [
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
    ("Fallout", "Fallout", "fallout477m", "com.alexbatalov.falloutce.rg477m/com.alexbatalov.falloutce.MainActivity", "",
     "Fallout Community Edition 477M, with your Steam/GOG game files."),
    ("Fallout 2", "Fallout 2", "fallout2477m", "com.alexbatalov.fallout2ce.rg477m/com.alexbatalov.fallout2ce.MainActivity", "",
     "Fallout 2 Community Edition 477M, with your Steam/GOG game files."),
    ("Perfect Dark", "Perfect Dark", "perfectdark477m", "com.perfectdark.port.rg477m/com.perfectdark.port.LauncherActivity", "",
     "The Perfect Dark port; pick your N64 ROM in its launcher once."),
    ("Morrowind", "The Elder Scrolls III: Morrowind", "openmw477m", "com.ast.openmw.rg477m/ui.activity.MainActivity",
     "\n --ez rg477m.autostart true", "OpenMW Mali Mobile with the mod list from RG477M-Morrowind.ps1; starts the game directly."),
    ("Ultima Online", "Ultima Online (UOAlive)", "ultimaonline477m", "com.mobileuo.mobileuo.rg477m/com.unity3d.player.UnityPlayerActivity", "",
     "MobileUO 477M set up for UOAlive, with controller play."),
    ("Old School RuneScape", "Old School RuneScape", "osrs477m", "com.rg477m.osrspad/com.rg477m.osrspad.PlayActivity", "",
     "The official Old School RuneScape app, opened through OSRS Pad 477M for controller play."),
    ("EverQuest Online Adventures", "EverQuest Online Adventures (Sandstorm)", "eqoa477m",
     "io.github.atrolle224.eqoa477m/io.github.dabdavis.eqoa.EqoaActivity", "",
     "EQOA Sandstorm 477M, the native EQOA client on eqoa.live; pick your Frontiers disc image in it once."),
]


def player(uid, name, desc, args, regex):
    return {"name": name, "uniqueId": uid, "description": desc, "acceptedFilenameRegex": regex,
            "amStartArguments": args, "killPackageProcesses": True,
            "killPackageProcessesWarning": False, "extra": ""}


def ra_player(official, short, core, label):
    base = next((p for p in official if p["uniqueId"] == f"{short}.ra64.{core}"), None)
    if base is None:
        sys.exit(f"{short}: no official player {short}.ra64.{core} to start from")
    args = (f"-n {RA}/com.retroarch.browser.retroactivity.RetroActivityFuture\n -e ROM {{file.path}}\n"
            f" -e LIBRETRO /data/data/{RA}/cores/{core}_libretro_android.so\n -e CONFIGFILE {RA_CFG}")
    return player(f"{short}.rg477m.ra.{core}", f"{short} - RetroArch 477M ({label})",
                  f"RetroArch 477M with {label}: RetroAchievements on, controllers set up for the RG477M.",
                  args, base["acceptedFilenameRegex"])


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

for folder, title, uid, component, extra, desc in PORTS:
    data = {
        "databaseVersion": 14,
        "revisionNumber": 1,
        "platform": {
            "name": title, "uniqueId": uid, "shortname": uid,
            "description": f"{desc} Point this platform at ROMs/{folder}, which holds {folder}.dpt.",
            "acceptedFilenameRegex": r"^(?!(?:\._|\.).*).*\.dpt$",
            "scraperSourceList": [], "boxArtAspectRatioId": 1, "useCustomBoxArtAspectRatio": False,
            "customBoxArtAspectRatio": None, "screenAspectRatioId": 1, "useCustomScreenAspectRatio": False,
            "customScreenAspectRatio": None, "retroAchievementsConsoleIdList": [], "extra": "",
        },
        "playerList": [player(f"{uid}.play", f"{uid} - {title}", desc, f"-n {component}{extra}\n --activity-clear-task",
                              r"^(?!(?:\._|\.).*).*\.dpt$")],
    }
    if component.startswith("com.rg477m.osrspad/"):
        # killing the package would stop the controller service it hosts
        data["playerList"][0]["killPackageProcesses"] = False
    fname = "Port - " + folder + ".json"
    with open(os.path.join(platforms_out, fname), "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    d = os.path.join(roms_out, folder)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, folder + ".dpt"), "w") as f:
        f.write(f"Daijishou placeholder: {title}\n")
    written.append((fname, folder, data["playerList"][0]["name"]))

for name, folder, first in written:
    print(f"{name:42} ROMs/{folder:22} default: {first}")
