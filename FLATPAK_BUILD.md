# Building Yatrium as Flatpak

This guide explains how to build Yatrium as a Flatpak with MPV bundled.

## Prerequisites

1. Install Flatpak and flatpak-builder:
```bash
sudo dnf install flatpak flatpak-builder  # Fedora
# or
sudo apt install flatpak flatpak-builder   # Ubuntu/Debian
```

2. Install the Freedesktop SDK:
```bash
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.freedesktop.Sdk//24.08
flatpak install flathub org.freedesktop.Platform//24.08
```

## Building

### Option 1: Using the Build Script (Recommended)

1. Make the script executable:
```bash
chmod +x build-flatpak.sh
```

2. Run the build script:
```bash
./build-flatpak.sh
```

This will:
- Build your Flutter app for Linux
- Prepare the bundle
- Build MPV from source
- Package everything into a Flatpak

### Option 2: Manual Build

1. Build the Flutter app:
```bash
flutter build linux --release
```

2. Prepare the bundle:
```bash
mkdir -p flatpak-bundle
cp -r build/linux/x64/release/bundle/* flatpak-bundle/
```

3. Build the Flatpak:
```bash
flatpak-builder --force-clean --repo=repo build-dir com.yantrium.Yatrium.json
```

4. Create the bundle:
```bash
flatpak build-bundle repo yatrium.flatpak com.yantrium.Yatrium
```

## Installing and Running

The generated `yatrium.flatpak` file is a **portable bundle** that can be installed on any Linux system with Flatpak installed.

### On the Build System

Install the Flatpak:
```bash
flatpak install --user yatrium.flatpak
```

Run the application:
```bash
flatpak run com.yantrium.Yatrium
```

### On Any Other Linux System

1. **Install Flatpak** (if not already installed):
   - **Fedora**: `sudo dnf install flatpak`
   - **Ubuntu/Debian**: `sudo apt install flatpak`
   - **Arch**: `sudo pacman -S flatpak`
   - **openSUSE**: `sudo zypper install flatpak`

2. **Install the Freedesktop runtime** (required for the app to run):
   ```bash
   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
   flatpak install flathub org.freedesktop.Platform//24.08
   ```

3. **Install the Yatrium bundle**:
   ```bash
   flatpak install --user yatrium.flatpak
   ```
   
   Or if you downloaded it:
   ```bash
   flatpak install --user /path/to/yatrium.flatpak
   ```

4. **Run the application**:
   ```bash
   flatpak run com.yantrium.Yatrium
   ```

The bundle is **completely portable** - you can copy `yatrium.flatpak` to any Linux system and install it there. All dependencies, including MPV, are bundled inside.

## MPV Bundling

The Flatpak manifest includes MPV as a module that gets built from source. This ensures:
- MPV is available in the Flatpak sandbox
- All necessary codecs and hardware acceleration support (Vulkan, VAAPI, VDPAU) are included
- Compatibility with `media_kit_libs_linux`

The `media_kit_libs_linux` package also bundles MPV, but building it in the Flatpak ensures it works correctly in the sandboxed environment.

## Troubleshooting

If you encounter issues:

1. **MPV not found**: Check that the MPV module built successfully in the build logs
2. **Video playback issues**: Ensure the finish-args include necessary permissions (wayland/x11, pulseaudio)
3. **Library errors**: Verify that all .so files from the Flutter bundle are copied to /app/lib

## Notes

- The manifest uses MPV v0.37.0 - update the tag if you need a different version
- The runtime version (23.08) can be updated to match your target platform
- All necessary permissions for video/audio playback are included in finish-args





