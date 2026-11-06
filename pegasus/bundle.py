#!/usr/bin/env python3
"""Build the RG477M Pegasus setup folder.

usage: bundle.py <out_dir> [apk ...]

<out_dir> gets the two folders to copy (Internal storage, SD card), the APKs
given, and README.txt.
"""
import os
import shutil
import sys

here = os.path.dirname(os.path.abspath(__file__))
out = sys.argv[1]
apks = sys.argv[2:]

internal = os.path.join(out, "Internal storage")
sd = os.path.join(out, "SD card")
shutil.rmtree(out, ignore_errors=True)

pf = os.path.join(internal, "pegasus-frontend")
shutil.copytree(os.path.join(here, "theme", "Daijishou477M"), os.path.join(pf, "themes", "Daijishou477M"))
shutil.copytree(os.path.join(here, "metafiles"), os.path.join(pf, "metafiles"))
shutil.copy(os.path.join(here, "settings.txt"), pf)
shutil.copytree(os.path.join(here, "RetroArch"), os.path.join(internal, "RetroArch"))
shutil.copytree(os.path.join(here, "ROMs"), os.path.join(sd, "ROMs"))

os.makedirs(os.path.join(out, "APKs"), exist_ok=True)
for apk in apks:
    shutil.copy(apk, os.path.join(out, "APKs"))
shutil.copy(os.path.join(here, "README.txt"), out)

for dirpath, _, files in os.walk(out):
    for f in files:
        if f == ".keep":
            os.remove(os.path.join(dirpath, f))
print(f"{out}: {len(apks)} APKs")
