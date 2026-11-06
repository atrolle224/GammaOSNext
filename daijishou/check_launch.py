#!/usr/bin/env python3
"""Check that the app and activity of every 477M player is in one of the APKs.

usage: check_launch.py <platforms dir> <aapt> <apk> ...

Only the 477M players and the ports are checked (unique id with "rg477m" or a port's
platform); the official players are for apps you install yourself.
"""
import glob
import json
import os
import re
import subprocess
import sys

platforms, aapt, apks = sys.argv[1], sys.argv[2], sys.argv[3:]
yours = {"com.explusalpha.SaturnEmu", "com.jagex.oldscape.android"}

activities = {}
for apk in apks:
    badging = subprocess.run([aapt, "dump", "badging", apk], capture_output=True, text=True).stdout
    pkg = re.search(r"^package: name='([^']+)'", badging, re.M).group(1)
    tree = subprocess.run([aapt, "dump", "xmltree", apk, "AndroidManifest.xml"], capture_output=True, text=True).stdout
    names = set(re.findall(r'A: android:name\(0x01010003\)="([^"]+)"', tree))
    activities[pkg] = names
    print(f"{os.path.basename(apk)}: {pkg}")

bad = 0
for path in sorted(glob.glob(os.path.join(platforms, "*.json"))):
    data = json.load(open(path, encoding="utf-8"))
    port = os.path.basename(path).startswith("Port - ")
    for p in data["playerList"]:
        if "rg477m" not in p["uniqueId"] and not port:
            continue
        m = re.search(r"-n ([^ /\n]+)/([^ \n]+)", p["amStartArguments"])
        if not m:
            print(f"{p['uniqueId']}: no -n component")
            bad += 1
            continue
        pkg, act = m.groups()
        if pkg in yours:
            print(f"{p['uniqueId']}: {pkg} (installed by you)")
            continue
        names = activities.get(pkg)
        full = pkg + act if act.startswith(".") else act
        # an activity is declared by its class name, which may not start with the package
        if names is None:
            print(f"{p['uniqueId']}: no APK is {pkg}")
            bad += 1
        elif full not in names and act not in names and ("." + full.rsplit(".", 1)[-1]) not in names:
            print(f"{p['uniqueId']}: {pkg} has no {full}")
            bad += 1
        else:
            print(f"{p['uniqueId']}: {pkg}/{full} ok")
sys.exit(1 if bad else 0)
