#!/usr/bin/env python3
"""A Daijishou wallpaper pack, cut down to the platforms of the RG477M setup.

usage: wallpapers.py <pack dir> <out dir> <platforms dir>

Copies the pack's index.json (with only those platforms' wallpapers and its default) and
the matching images to <out>, keeping the pack's own layout for Daijishou.
"""
import glob
import json
import os
import shutil
import sys

pack, out, platforms = sys.argv[1:]
shortnames = {"android", "ports"}
for path in glob.glob(os.path.join(platforms, "*.json")):
    shortnames.add(json.load(open(path, encoding="utf-8"))["platform"]["shortname"])

index = json.load(open(os.path.join(pack, "index.json"), encoding="utf-8"))
keep = [w for w in index["wallpaperList"] if w.get("matchPlatformShortname") in shortnames]
index["wallpaperList"] = keep
files = {w["filename"] for w in keep}
for key in ("defaultWallpaperFilename", "previewThumbnailFilename"):
    if index.get(key):
        files.add(index[key])

os.makedirs(out, exist_ok=True)
for name in sorted(files):
    if os.path.exists(os.path.join(pack, name)):
        shutil.copy(os.path.join(pack, name), out)
with open(os.path.join(out, "index.json"), "w", encoding="utf-8") as f:
    json.dump(index, f, indent=2, ensure_ascii=False)
print(f"{out}: {len(keep)} wallpapers of {index.get('name')} for {', '.join(sorted(shortnames))}")
