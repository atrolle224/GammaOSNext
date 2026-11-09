#!/usr/bin/env python3
"""Patches on Nexus for the RG477M custom list that the list itself doesn't install.

usage: nexus_patch_scan.py <expanded-vanilla api json> <out json> <out md>

For every kept mod on Nexus, reads its files and description (Nexus' public GraphQL API) and
reports files and description lines that mention a patch, or another kept mod, which the list
doesn't already download.
"""
import json
import re
import sys
import time
import urllib.request

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from make_rg477m_custom import kept  # noqa: E402

GRAPHQL = "https://api.nexusmods.com/v2/graphql"
FILES = """query($modId: ID!, $gameId: ID!) {
  modFiles(modId: $modId, gameId: $gameId) { fileId name description category version uri }
}"""
MOD = """query($ids: [CompositeDomainWithIdInput!]!) {
  legacyModsByDomain(ids: $ids) { nodes { modId name summary description } }
}"""


def gql(query, variables):
    req = urllib.request.Request(GRAPHQL, json.dumps({"query": query, "variables": variables}).encode(),
                                 {"Content-Type": "application/json", "User-Agent": "RG477M-setup"})
    with urllib.request.urlopen(req, timeout=60) as r:
        out = json.load(r)
    if out.get("errors"):
        raise RuntimeError(out["errors"][0].get("message"))
    return out["data"]


def text(html):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>|\[/?[a-z]+[^\]]*\]", " ", html or "")).strip()


mods = json.load(open(sys.argv[1], encoding="utf-8"))
keep = [m for m in mods if kept(m)]
names = {m["name"]: m for m in keep}
# short names to spot mentions: "Tamriel Rebuilt", "OAAB Grazelands", ...
spot = {n: re.compile(re.escape(re.sub(r"\s*[-(].*$", "", n)), re.I) for n in names if len(n) > 6}

report = []
for m in keep:
    found = re.search(r"nexusmods\.com/morrowind/mods/(\d+)", m["url"] or "")
    if not found:
        continue
    mod_id = found.group(1)
    picked = {str(di.get("nexus_file_id")) for di in m["download_info"] if di.get("nexus_file_id")}
    entry = {"mod": m["name"], "nexus": f"https://www.nexusmods.com/morrowind/mods/{mod_id}",
             "files": [], "mentions": [], "error": None}
    try:
        files = gql(FILES, {"modId": mod_id, "gameId": "100"})["modFiles"]
        for f in files:
            if str(f["fileId"]) in picked or f["category"] in ("ARCHIVED", "DELETED", "OLD_VERSION"):
                continue
            blob = f"{f['name']} {text(f['description'])}"
            others = [n for n, rx in spot.items() if n != m["name"] and rx.search(blob)]
            if re.search(r"patch|compat", blob, re.I) or others:
                entry["files"].append({"name": f["name"], "category": f["category"],
                                       "description": text(f["description"])[:300], "mentions": others})
        nodes = gql(MOD, {"ids": [{"gameDomain": "morrowind", "modId": int(mod_id)}]})["legacyModsByDomain"]["nodes"]
        if nodes:
            for sentence in re.split(r"(?<=[.!?])\s+", text(nodes[0].get("description"))):
                if re.search(r"patch|compatib|incompatib|conflict", sentence, re.I):
                    others = [n for n, rx in spot.items() if n != m["name"] and rx.search(sentence)]
                    entry["mentions"].append({"text": sentence[:300], "mentions": others})
    except Exception as e:  # report and go on: one mod must not stop the scan
        entry["error"] = str(e)
    report.append(entry)
    time.sleep(0.3)

json.dump(report, open(sys.argv[2], "w", encoding="utf-8"), indent=1, ensure_ascii=False)
with open(sys.argv[3], "w", encoding="utf-8") as md:
    md.write("# Patches on Nexus that the RG477M list doesn't install\n\n")
    for e in report:
        if not (e["files"] or e["mentions"] or e["error"]):
            continue
        md.write(f"## {e['mod']}\n{e['nexus']}\n\n")
        if e["error"]:
            md.write(f"- error: {e['error']}\n")
        for f in e["files"]:
            md.write(f"- FILE [{f['category']}] {f['name']}: {f['description']}"
                     f"{' (mentions ' + ', '.join(f['mentions']) + ')' if f['mentions'] else ''}\n")
        for s in e["mentions"]:
            md.write(f"- PAGE: {s['text']}{' (mentions ' + ', '.join(s['mentions']) + ')' if s['mentions'] else ''}\n")
        md.write("\n")
print(f"{len(report)} mods scanned, {sum(1 for e in report if e['error'])} errors, "
      f"{sum(len(e['files']) for e in report)} files and {sum(len(e['mentions']) for e in report)} page notes")
