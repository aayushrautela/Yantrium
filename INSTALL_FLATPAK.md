# Installing Yatrium Flatpak

The `yatrium.flatpak` file is a **portable bundle** that works on any Linux distribution with Flatpak installed.

## Quick Install

1. **Install Flatpak** (one-time setup):
   ```bash
   # Fedora
   sudo dnf install flatpak
   
   # Ubuntu/Debian
   sudo apt install flatpak
   
   # Arch
   sudo pacman -S flatpak
   ```

2. **Add Flathub repository** (for the runtime):
   ```bash
   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
   ```

3. **Install the runtime** (one-time, shared by all Flatpak apps):
   ```bash
   flatpak install flathub org.freedesktop.Platform//24.08
   ```

4. **Install Yatrium**:
   ```bash
   flatpak install --user yatrium.flatpak
   ```

5. **Run Yatrium**:
   ```bash
   flatpak run com.yantrium.Yatrium
   ```

## What's Included

- ✅ Yatrium application (Flutter app)
- ✅ MPV player (built from source with hardware acceleration)
- ✅ All required libraries and dependencies
- ✅ Works on any Linux distribution

The bundle is **self-contained** - everything needed to run Yatrium is included except for the base Flatpak runtime (which is shared by all Flatpak apps).

## Distribution

You can distribute the `yatrium.flatpak` file to anyone:
- Share via download link
- Host on your website
- Distribute via USB drive
- Upload to file sharing services

Users just need Flatpak installed and the Freedesktop runtime (step 3 above).






