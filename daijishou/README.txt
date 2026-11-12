RG477M DAIJISHOU SETUP
======================

Daijishou with every emulator and port wired to the RG477M builds. No root needed.

0. FIRST: THE CONTROLLER MODE
   Pull down the drop-down bar and set the controller mode to Xbox (if it is
   called Swap ABXY, turn the swap off). Everything here expects the Xbox
   layout: A is the bottom face button. To check, open OSRS Pad 477M and press
   the bottom face button: its controller test should say BUTTON_A (96).

1. INSTALL THE APPS
   - Daijishou from the Play Store (it is free).
   - The APKs in the APKs folder you use. GameCube and Wii start Dolphin MMJR2
     477M; Dolphin 477M is the second player there. Both have RetroAchievements
     (MMJR2: Settings > Config > General > RetroAchievements Account).

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
     snes9x, genesis_plus_gx, mednafen_ngp, swanstation, pcsx_rearmed,
     dosbox_pure (DOS), mupen64plus_next (N64, "Mupen64Plus-Next GLES3").
   - Settings > Achievements > sign in to RetroAchievements (it is already on).
   RetroArch games from Daijishou use /RetroArch/retroarch.cfg, with the RG477M
   controller profile; BIOS files go in /RetroArch/system (Sega CD: bios_CD_U.bin;
   PlayStation: scph5501.bin).

   DOS (DOSBox Pure): put each game as a .zip in ROMs/dos (no unzipping needed).
   L3 opens its menu: the start menu, the on-screen keyboard (L/R switch tabs)
   and the controller mapper. Games it knows get a controller layout by
   themselves; the right stick is the mouse.

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
   RG477M's Internal storage\Documents (you get Documents/Morrowind Android with
   Data Files and momw inside). In OpenMW Mali Mobile's settings keep "Use the
   installed mod list" ticked. The Morrowind platform starts the game directly
   with the list's load order and grass; the app uses its own handheld shadow
   and shader settings instead of the list's PC ones (change them in the app).

OLD SCHOOL RUNESCAPE WITH THE CONTROLLER (no root needed)
   1. Install Old School RuneScape from the Play Store, and OSRS-Pad-477M.apk.
   2. Open OSRS Pad 477M > Accessibility settings and turn it on. If Android says
      it's a restricted setting: OSRS Pad 477M > App info > the ⋮ menu (top right)
      > Allow restricted settings, then turn it on again.
   3. Start Old School RuneScape from the Ports. Start shows the controls.

PLAYSTATION
   PlayStation starts RetroArch 477M with SwanStation, the open-source branch of
   DuckStation's emulator, already set up for the RG477M: 4x resolution (sharp at
   1280x960), PGXP geometry and texture correction, true colour, fast boot, the
   controller profile and RetroAchievements. Its options are in
   /RetroArch/config/SwanStation/SwanStation.opt (Quick Menu > Core Options).
   It needs a PlayStation BIOS, e.g. scph5501.bin, in /RetroArch/system.
   The DuckStation app itself (Play Store) is the third player: hold the game in
   Daijishou to pick it. DuckStation is not open source any more, so it is used
   as it is; sign in to RetroAchievements in its Settings > Achievements.
