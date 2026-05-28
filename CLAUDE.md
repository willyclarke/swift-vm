# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal

A macOS app that creates and runs GUI Linux (and macOS) virtual machines using Apple's [Virtualization framework](https://developer.apple.com/documentation/virtualization). The user owns all source code. Apple's sample project lives in `apple-examples/` as a reference.

## Build & Run

This is an Xcode project — build and run via Xcode or `xcodebuild`:

```bash
# Build
xcodebuild -project SwiftVM.xcodeproj -scheme SwiftVM -configuration Debug build

# Run (after build)
open build/Debug/SwiftVM.app

# Run tests
xcodebuild test -project SwiftVM.xcodeproj -scheme SwiftVM
```

The app requires a **Developer Team ID** set in Signing & Capabilities to satisfy the `com.apple.security.virtualization` entitlement. Without a signed team, the VM will fail to start at runtime.

## Required Entitlement

Every target that creates a `VZVirtualMachine` must have this entitlement in its `.entitlements` file:

```xml
<key>com.apple.security.virtualization</key>
<true/>
```

## Virtualization Framework Architecture

The core pipeline for any VM:

1. **Configure** — build a `VZVirtualMachineConfiguration` with CPU count, memory, platform, bootloader, storage, network, graphics, audio, input devices.
2. **Validate** — call `configuration.validate()` before instantiating (throws on misconfiguration).
3. **Instantiate** — `VZVirtualMachine(configuration:)` — must be done on the main queue.
4. **Display** — assign to a `VZVirtualMachineView` and set `automaticallyReconfiguresDisplay = true` (macOS 14+).
5. **Start** — `virtualMachine.start(completionHandler:)` — runs the guest OS.
6. **Delegate** — implement `VZVirtualMachineDelegate` to handle `guestDidStop` and `didStopWithError`.

`VZVirtualMachine` operations must run on the **main queue**.

## VM Bundle Layout

Each Linux VM is persisted as a bundle directory (e.g. `~/GUI Linux VM.bundle/`):

| File | Contents |
|------|----------|
| `Disk.img` | Raw disk image (pre-allocated, e.g. 64 GB via `truncate(atOffset:)`) |
| `NVRAM` | EFI variable store (`VZEFIVariableStore`) |
| `MachineIdentifier` | Serialised `VZGenericMachineIdentifier` data |

**First boot (install):** create a new `MachineIdentifier` + `VZEFIVariableStore`, attach the ISO as a `VZUSBMassStorageDeviceConfiguration`.  
**Subsequent boots:** load existing `MachineIdentifier` + `VZEFIVariableStore` from disk; no ISO needed.

## Key Device Configurations (Linux)

| Capability | Type |
|-----------|------|
| Boot | `VZEFIBootLoader` with `VZEFIVariableStore` |
| Platform | `VZGenericPlatformConfiguration` + `VZGenericMachineIdentifier` |
| Main disk | `VZVirtioBlockDeviceConfiguration` |
| Network | `VZVirtioNetworkDeviceConfiguration` with `VZNATNetworkDeviceAttachment` |
| Graphics | `VZVirtioGraphicsDeviceConfiguration` with `VZVirtioGraphicsScanoutConfiguration` |
| Audio in/out | `VZVirtioSoundDeviceConfiguration` |
| Keyboard | `VZUSBKeyboardConfiguration` |
| Pointer | `VZUSBScreenCoordinatePointingDeviceConfiguration` |
| Clipboard sharing | `VZVirtioConsoleDeviceConfiguration` + `VZSpiceAgentPortAttachment` (requires `spice-vdagent` installed in guest) |

## Architecture Notes for This Project

- The Apple sample puts everything in `AppDelegate` — for a production app, extract VM lifecycle into a dedicated `VirtualMachineManager` (or `@Observable` model) so the UI layer stays thin.
- To support multiple VMs simultaneously, each `VZVirtualMachine` needs its own bundle path, configuration, and view.
- `VZVirtualMachineView` is an `NSView` subclass — embed it in SwiftUI via `NSViewRepresentable` if building a SwiftUI app.
- CPU count defaults to `processorCount - 1`; memory defaults to 4 GiB — both must stay within `VZVirtualMachineConfiguration.minimumAllowed*` / `maximumAllowed*` bounds.
- ISO architecture must match host: `aarch64`/`arm64` on Apple silicon, `x86_64`/`amd64` on Intel.

## Reference

- Apple sample code: `apple-examples/GUILinuxVirtualMachineSampleApp/AppDelegate.swift`
- Apple documentation: https://developer.apple.com/documentation/virtualization
