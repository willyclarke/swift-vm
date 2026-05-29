# SwiftVM

A macOS app that creates and runs GUI Linux virtual machines using Apple's [Virtualization framework](https://developer.apple.com/documentation/virtualization). Full Swift source — no third-party dependencies.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel Mac
- Xcode 15+
- Apple Developer account (required for the `com.apple.security.virtualization` entitlement)

## Building and running the GUI app

1. Open `SwiftVM.xcodeproj` in Xcode.
2. In the project settings → **Signing & Capabilities**, set your **Team**.
3. Press **⌘R** to build and run.

On first launch, click **Start** to install the OS. The app will prompt for an ISO and create a VM bundle at `~/Linux VM.bundle/`.

## Installing and distributing

A `Makefile` is provided for building outside Xcode:

```bash
make build     # compile Release .app
make install   # build and copy to /Applications
make dmg       # build and package as SwiftVM-<version>.dmg
make notarize  # submit DMG to Apple notarization and staple ticket
make clean     # remove build artefacts
```

**Notarization** (`make notarize`) requires:
- A **Developer ID Application** certificate in your keychain (set in Xcode's Signing & Capabilities instead of the default Development certificate)
- **Hardened Runtime** enabled in Signing & Capabilities
- A stored `notarytool` credential profile — run once:

```bash
xcrun notarytool store-credentials "swiftvm-notarytool" \
  --apple-id "you@example.com" \
  --team-id "XXXXXXXXXX" \
  --password "<app-specific-password>"
```

An app-specific password can be generated at [appleid.apple.com](https://appleid.apple.com).

## Installing Void Linux

The Void Linux live ISO does not include `void-installer`. Install manually:

```bash
# Inside the live environment
cfdisk /dev/vda            # GPT → 512M EFI System + rest Linux filesystem
mkfs.fat -F32 /dev/vda1
mkfs.ext4 /dev/vda2
mount /dev/vda2 /mnt/void
mkdir -p /mnt/void/boot/efi && mount /dev/vda1 /mnt/void/boot/efi
xbps-install -Sy -r /mnt/void -R https://repo-default.voidlinux.org/current/aarch64 base-system
mount --rbind /sys /mnt/void/sys && mount --rbind /dev /mnt/void/dev && mount --rbind /proc /mnt/void/proc
cp /etc/resolv.conf /mnt/void/etc/
chroot /mnt/void /bin/bash

# Inside chroot — note: kernel must be installed explicitly, base-system does not include it
xbps-install linux
xbps-install grub-arm64-efi   # or grub-x86_64-efi on Intel
grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=void
update-grub
passwd root
xbps-reconfigure -fa
exit
umount -R /mnt/void && shutdown -h now
```

After first boot, run the post-install script from within the VM:

```bash
bash /path/to/postinstall/void-linux/postinstall.sh
```

This installs XFCE, LightDM, PipeWire audio, clipboard sharing (SPICE), and configures all required services.

## Running headlessly from the command line

Use the script in `scripts/void-linux/` to start the VM without a window — interact via SSH instead:

```bash
./scripts/void-linux/run.sh                  # uses ~/Linux VM.bundle
./scripts/void-linux/run.sh "My Other VM"    # uses ~/My Other VM.bundle
```

The script compiles the Swift CLI tool on first run and caches the binary as `.swiftvm-cli`. It recompiles automatically if `main.swift` changes. Press **Ctrl+C** to stop the VM gracefully.

Find the VM's IP address:

```bash
# From macOS — check DHCP leases (the VM MAC address is in ~/Linux VM.bundle/MACAddress)
cat ~/Linux\ VM.bundle/MACAddress

# Or from inside the VM
ip addr show eth0
```

The MAC address is persisted across reboots so the VM receives the same DHCP lease each time.

## VM bundle layout

```
~/Linux VM.bundle/
├── Disk.img          # 64 GB sparse disk image
├── NVRAM             # EFI variable store
├── MachineIdentifier # VZGenericMachineIdentifier data
├── MACAddress        # Persistent MAC (plain text, e.g. "aa:bb:cc:dd:ee:ff")
└── Config.json       # Per-VM CPU and memory settings
```

VM bundles are excluded from git via `.gitignore`.

## Devices configured

| Device | Type |
|---|---|
| CPU | All cores minus one, min 1 |
| RAM | 4 GB |
| Disk | VirtIO block (`Disk.img`) |
| Network | VirtIO NAT |
| Graphics | VirtIO GPU (GUI app only) |
| Audio | VirtIO sound (GUI app only) |
| Keyboard | USB (GUI app only) |
| Pointer | USB (GUI app only) |
| Clipboard | SPICE console port (GUI app only) |
