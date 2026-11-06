#!/usr/bin/env python3
"""A stand-in for the RetroAchievements API for the theme test: a user summary and images.

usage: ra_mock.py <dir>   (writes the files; serve <dir> over HTTP)
"""
import json
import os
import subprocess
import sys

root = sys.argv[1]
os.makedirs(os.path.join(root, "API"), exist_ok=True)
os.makedirs(os.path.join(root, "Badge"), exist_ok=True)
os.makedirs(os.path.join(root, "Images"), exist_ok=True)
os.makedirs(os.path.join(root, "UserPic"), exist_ok=True)


def img(path, colour, size, text):
    subprocess.run(["convert", "-size", size, f"gradient:{colour}-black", "-gravity", "center",
                    "-pointsize", "18", "-fill", "white", "-annotate", "0", text,
                    os.path.join(root, path)], check=True)


img("UserPic/Andre477M.png", "#2c7be5", "128x128", "AT")
img("Images/012345.png", "#7a3ff0", "96x96", "SM")
achievements = [
    ("Ridley's End", "Defeat Ridley", 25, 1, "2026-11-05 21:14:09"),
    ("Speed Booster", "Find the Speed Booster", 10, 1, "2026-11-05 20:52:40"),
    ("Draygon Down", "Defeat Draygon", 25, 1, "2026-11-05 20:31:02"),
    ("Grapple", "Find the Grapple Beam", 5, 0, "2026-11-04 22:10:55"),
    ("Kraid Slayer", "Defeat Kraid", 10, 1, "2026-11-04 21:48:33"),
    ("Crocomire's Bones", "Defeat Crocomire", 10, 1, "2026-11-04 21:02:17"),
    ("Spore Spawn", "Defeat Spore Spawn", 5, 1, "2026-11-03 19:40:00"),
    ("Charge!", "Find the Charge Beam", 3, 0, "2026-11-03 19:12:44"),
]
recent = {}
for i, (title, desc, pts, hc, date) in enumerate(achievements):
    badge = f"{1000 + i:05d}"
    img(f"Badge/{badge}.png", ["#e8b923", "#ff4f6d", "#3cb371", "#5a8dee"][i % 4], "64x64", str(pts))
    recent[str(9000 + i)] = {"ID": 9000 + i, "GameID": 12345, "GameTitle": "Super Metroid", "Title": title,
                             "Description": desc, "Points": pts, "BadgeName": badge, "IsAwarded": "1",
                             "DateAwarded": date, "HardcoreAchieved": hc}
summary = {
    "User": "Andre477M",
    "UserPic": "/UserPic/Andre477M.png",
    "Motto": "Handheld hunter",
    "RichPresenceMsg": "Exploring Maridia, 14 Missiles, 3 Energy Tanks",
    "TotalPoints": 12840,
    "TotalSoftcorePoints": 312,
    "TotalTruePoints": 33120,
    "Rank": 18422,
    "TotalRanked": 96512,
    "LastGameID": 12345,
    "LastGame": {"ID": 12345, "Title": "Super Metroid", "ConsoleName": "SNES/Super Famicom",
                 "ImageIcon": "/Images/012345.png"},
    "RecentlyPlayed": [{"GameID": 12345, "Title": "Super Metroid", "ConsoleName": "SNES/Super Famicom",
                        "ImageIcon": "/Images/012345.png"}],
    "Awarded": {"12345": {"NumPossibleAchievements": 72, "PossibleScore": 750, "NumAchieved": 41,
                          "ScoreAchieved": 380, "NumAchievedHardcore": 35, "ScoreAchievedHardcore": 330}},
    "RecentAchievements": {"12345": recent},
}
with open(os.path.join(root, "API", "API_GetUserSummary.php"), "w") as f:
    json.dump(summary, f)
