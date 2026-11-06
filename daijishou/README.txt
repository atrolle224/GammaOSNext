RG477M DAIJISHOU SETUP
======================

Daijishou with every emulator and port wired to the RG477M builds. No root needed.

1. INSTALL THE APPS
   - Daijishou from the Play Store (it is free).
   - The APKs in the APKs folder you use. GameCube and Wii start Dolphin MMJR2
     477M; Dolphin 477M is the second player there (it has RetroAchievements).

2. COPY THE FOLDERS
   - "Internal storage" goes to the root of internal storage (you get /RetroArch).
   - "SD card" goes to the root of the SD card (you get /ROMs, one folder per
     system, plus a folder with a placeholder file for each port).
   - "Daijishou platforms" goes anywhere on the device, e.g. Download.

3. IMPORT THE PLATFORMS IN DAIJISHOU
   In Daijishou's library settings, use Import platform and pick each .json in
   "Daijishou platforms" (the menu names can differ a little between Daijishou
   versions). An imported platform has the 477M app as its first player, which
   Daijishou uses unless you pick another.
   Then give each platform its sync path: its folder in ROMs on the SD card
   (gb, snes, ps2...; a port's own folder, e.g. ROMs/Fallout).

4. RETROARCH 477M
   Start one RetroArch game from Daijishou, then in RetroArch:
   - Main Menu > Online Updater > Core Downloader: gambatte, mgba, fceumm,
     snes9x, genesis_plus_gx, mednafen_ngp, pcsx_rearmed.
   - Settings > Achievements > sign in to RetroAchievements (it is already on).
   RetroArch games from Daijishou use /RetroArch/retroarch.cfg, with the RG477M
   controller profile; BIOS files go in /RetroArch/system (Sega CD: bios_CD_U.bin;
   PlayStation: scph5501.bin).

5. LOOK AND FEEL
   - Wallpapers: Epic ArtBook Noir (by Jamesinorbit, from Daijishou's gallery).
     In Daijishou's settings, open Wallpaper packs and download Epic ArtBook
     Noir there; it matches the platforms by their short names, so every
     imported platform gets its wallpaper. Offline, the same pack for these
     platforms is in "Daijishou wallpapers/EpicArtBookNoir" (with its index.json)
     to import from the device, or to set per platform.
   - RetroAchievements: sign in in Daijishou's settings, then add its
     RetroAchievements widgets on the Widgets page.
   - Your Android apps: Daijishou's Android platform.

PHANTASY STAR ONLINE EPISODE I & II ON SCHTSERV
   Both Dolphin MMJR2 477M and Dolphin 477M start PSO Episode I & II (US) with
   SCHTSERV's Broadband Adapter (tapserver 3.18.217.27:9501) and a raw memory card.
   1. Register your game's serial at https://api.schtserv.com/MyHL/ first.
   2. In PSO: Options > Network Option > Provider Option > Yes. Create the network
      file on the memory card, then Network Setup > pick a provider > Edit Menu:
      "Automatically Obtain an IP Address", "Do not automatically Disconnect",
      DNS Manual, primary 3.18.217.27, secondary blank. Leave the proxy empty, save.
   3. Choose Online on the title screen.
   If you keep getting error 102: turn on the cheat "SCHTSERV: fix error 102" for
   your version in PSO's game settings, and Enable Cheats in Dolphin's settings.

MORROWIND WITH THE EXPANDED VANILLA MOD LIST
   On your PC, run RG477M-Morrowind.ps1 (GammaOSNext/ports/openmw). It makes
   C:\Morrowind477M\Morrowind Android and a zip of it; put that folder in the
   RG477M's Internal storage\Documents. The Morrowind platform starts the game
   directly with the list's load order.
