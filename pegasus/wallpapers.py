#!/usr/bin/env python3
"""Convert a Daijishou platform wallpaper pack for the Daijishou 477M Pegasus theme.

usage: wallpapers.py <pack dir> <theme dir>

Each wallpaper is cropped to the RG477M's 4:3 screen and saved as
<theme>/assets/wallpapers/<shortname>.jpg. Platforms the pack has no
wallpaper for keep the theme's colour card: a pack's default wallpaper
usually names a platform of its own.
"""
import json
import os
import subprocess
import sys

pack, theme = sys.argv[1:]
out = os.path.join(theme, "assets", "wallpapers")
os.makedirs(out, exist_ok=True)

# the theme's platforms; the pack names most of them the same way
platforms = ["gb", "gbc", "gba", "nes", "snes", "n64", "nds", "gc", "wii", "master", "genesis",
             "gamegear", "segacd", "saturn", "dreamcast", "ngpc", "psx", "ps2", "psp", "xbox",
             "ports", "android"]
info = json.load(open(os.path.join(pack, "index.json")))
files = {w["matchPlatformShortname"]: w["filename"] for w in info["wallpaperList"]}

done = 0
for short in platforms:
    name = files.get(short) or (short + ".png" if os.path.exists(os.path.join(pack, short + ".png")) else None)
    if not name:
        continue
    subprocess.run(["convert", os.path.join(pack, name), "-resize", "1280x960^", "-gravity", "center",
                    "-extent", "1280x960", "-strip", "-quality", "86", os.path.join(out, short + ".jpg")],
                   check=True)
    done += 1

with open(os.path.join(out, "CREDITS.txt"), "w") as f:
    f.write(f"Wallpapers: {info['name']} by {', '.join(info['authors'])}, a Daijishou platform wallpaper pack.\n"
            "Based on: " + ", ".join(info.get("sources", [])) + "\n"
            "Cropped to 4:3 for the RG477M.\n")
print(f"{out}: {done} wallpapers from {info['name']}")
