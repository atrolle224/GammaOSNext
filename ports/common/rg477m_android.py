#!/usr/bin/env python3
"""RG477M packaging for an Android Gradle app: its own package beside the original, arm64 only.

usage: rg477m_android.py <app/build.gradle> <strings.xml> <application id> <app name>
"""
import re
import sys

gradle, strings, app_id, app_name = sys.argv[1:5]

with open(gradle) as f:
    s = f.read()
s, n = re.subn(r"""applicationId\s+(['"])[^'"]+\1""", f"applicationId '{app_id}'", s, count=1)
if n != 1:
    sys.exit(f"{gradle}: no applicationId")
s = re.sub(r"abiFilters\s+[^\n]+", "abiFilters 'arm64-v8a'", s)
s = re.sub(r"\n\s*applicationIdSuffix\s+[^\n]+", "", s)
with open(gradle, "w") as f:
    f.write(s)

with open(strings) as f:
    s = f.read()
s, n = re.subn(r'(<string name="app_name"[^>]*>)[^<]*(</string>)', rf"\g<1>{app_name}\g<2>", s, count=1)
if n != 1:
    sys.exit(f"{strings}: no app_name")
with open(strings, "w") as f:
    f.write(s)
print(f"{gradle}: {app_id}, \"{app_name}\", arm64")
