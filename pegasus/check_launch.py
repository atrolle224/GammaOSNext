#!/usr/bin/env python3
"""Check that every app and activity the game lists start is in one of the APKs.

usage: check_launch.py <aapt> <apk> ...
"""
import glob
import os
import re
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
aapt, apks = sys.argv[1], sys.argv[2:]
yours = {"com.explusalpha.SaturnEmu", "com.jagex.oldscape.android"}

activities = {}
for apk in apks:
    badging = subprocess.run([aapt, "dump", "badging", apk], capture_output=True, text=True).stdout
    pkg = re.search(r"^package: name='([^']+)'", badging, re.M).group(1)
    tree = subprocess.run([aapt, "dump", "xmltree", apk, "AndroidManifest.xml"], capture_output=True, text=True).stdout
    names = set(re.findall(r'A: android:name\(0x01010003\)="([^"]+)"', tree))
    activities[pkg] = {pkg + n if n.startswith(".") else n for n in names}
    print(f"{os.path.basename(apk)}: {pkg}")

bad = 0
files = glob.glob(os.path.join(here, "ROMs", "*.txt")) + glob.glob(os.path.join(here, "metafiles", "*.txt"))
for path in sorted(files):
    text = open(path).read()
    launch = re.findall(r"^launch: (.*(?:\n  .*)*)", text, re.M)
    for cmd in launch:
        m = re.search(r"-n ([^ /\n]+)/([^ \n]+)", cmd)
        pkg = m.group(1) if m else re.search(r"-p ([^ \n]+)", cmd).group(1)
        if pkg in yours:
            continue
        if pkg not in activities:
            print(f"{os.path.basename(path)}: no APK is {pkg}")
            bad += 1
            continue
        if m:
            act = m.group(2)
            act = pkg + act if act.startswith(".") else act
            if act not in activities[pkg]:
                print(f"{os.path.basename(path)}: {pkg} has no {act}")
                bad += 1
                continue
        print(f"{os.path.basename(path)}: {pkg} ok")
sys.exit(1 if bad else 0)
