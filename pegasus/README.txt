RG477M PEGASUS SETUP
====================

A Daijishou-style Pegasus library with every emulator and port already wired up.
No root needed.

1. INSTALL THE APPS
   Install Pegasus.apk and Vita3K.apk from the APKs folder, then the emulator
   APKs you use (the list below says which app runs which system).

2. COPY THE FOLDERS
   - Everything in "Internal storage" goes to the root of internal storage
     (you get /pegasus-frontend and /RetroArch next to Download, DCIM...).
   - Everything in "SD card" goes to the root of the SD card (you get /ROMs).
   A file manager, or a USB cable from a PC, both work.

3. PUT YOUR GAMES IN
   Each system has its own folder in ROMs on the SD card:
     gb gbc gba nes snes n64 nds gc wii master genesis gamegear segacd
     saturn dreamcast ngpc psx ps2 psp psvita xbox
   BIOS files for RetroArch go in /RetroArch/system on internal storage
   (Sega CD: bios_CD_U.bin, bios_CD_E.bin or bios_CD_J.bin; PlayStation:
   scph5501.bin). The other emulators ask for theirs on first start.

   PS Vita: install the game in Vita3K first, then make an empty file in
   ROMs/psvita named after the game's title ID, e.g. PCSE00120.psvita.

4. FIRST START OF PEGASUS
   Open Pegasus and allow file access. Press Start > Settings >
   Set game directories > add the ROMs folder on the SD card. Go back:
   the library fills in. Systems with no games stay hidden.
   To make Pegasus the home screen: Android Settings > Apps > Default apps >
   Home app > Pegasus.

5. FIRST START OF RETROARCH 477M
   Start any RetroArch game from Pegasus once, then in RetroArch:
   - Main Menu > Online Updater > Core Downloader: get the cores below.
   - Main Menu > Online Updater > Update Controller Profiles.
   - Settings > Achievements > sign in to RetroAchievements (it is already on).
   Always start RetroArch games from Pegasus: they use /RetroArch/retroarch.cfg,
   which keeps your login, saves (/RetroArch/saves) and states together.

CONTROLS IN PEGASUS
   D-pad / stick   move            A      open / play
   B               back            X      favourite
   Y               sort A-Z / recent       L1 R1  previous / next letter
   L2 R2           page up / down  Start  Pegasus menu
   Recently Played and Favorites appear first on the carousel once they have games.

WHICH APP RUNS WHAT
   RetroArch 477M (com.retroarch.rg477m), cores:
     Game Boy, Game Boy Color: gambatte     Game Boy Advance: mgba
     NES: fceumm                            SNES: snes9x
     Master System, Genesis, Game Gear, Sega CD: genesis_plus_gx
     Neo Geo Pocket Color: mednafen_ngp     PlayStation: pcsx_rearmed
   Nintendo 64: Mupen64Plus FZ 477M         Nintendo DS: melonDS 477M
   GameCube, Wii: Dolphin 477M              Dreamcast: Flycast 477M
   PlayStation 2: ARMSX2 Net                PSP: PPSSPP 477M
   PS Vita: Vita3K                          Xbox: hakuX
   Saturn: Saturn.emu (your own copy)
   Ports: Fallout CE, Fallout 2 CE, Perfect Dark, OpenMW 477M,
     MobileUO 477M (UOAlive), Old School RuneScape (from the Play Store)

   To use a different app for a system (the official Dolphin, the ARMSX2 DNS
   build, Yaba Sanshiro 2...), open SD card/ROMs/metadata.pegasus.txt: each
   system has the other app's launch line commented out under its own.

ARTWORK (optional)
   Box art: Pegasus reads ROMs/<system>/media/<game name>/boxFront.png (also
   screenshot.png, logo.png, background.png). Skraper can make these.
   Platform wallpapers: put <system>.jpg (gb.jpg, snes.jpg, ps2.jpg...) in
   pegasus-frontend/themes/Daijishou477M/assets/wallpapers, and a logo
   <system>.png in .../assets/logos. Without them each platform gets its own colour.
