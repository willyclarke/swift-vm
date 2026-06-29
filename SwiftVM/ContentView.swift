import SwiftUI

struct ContentView: View {
    @StateObject private var manager = VirtualMachineManager()
    @State private var confirmDelete = false
    @AppStorage("sharedFoldersExpanded") private var sharedFoldersExpanded = true

    var body: some View {
        launchView
            .frame(minWidth: 400, minHeight: 300)
            .focusedObject(manager)
            .background(BackgroundView())
            .alert("VM Error", isPresented: $manager.hasError) {
                Button("OK") { }
            } message: {
                Text(manager.errorMessage ?? "An unknown error occurred.")
            }
    }

    private var launchView: some View {
        VStack(spacing: 24) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Swift VM")
                .font(.largeTitle.bold())

            bundleSelector

            if manager.isStarting {
                ProgressView("Starting virtual machine…")
            } else {
                VStack(spacing: 12) {
                    Button(manager.bundleExists ? "Start Virtual Machine" : "Install VM…") {
                        manager.start()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return)
                    .disabled(manager.isRunning)

                    if manager.bundleExists && !manager.isRunning {
                        Button("Delete & Reinstall", role: .destructive) {
                            confirmDelete = true
                        }
                        .buttonStyle(.borderless)
                        .confirmationDialog(
                            "Delete \"\(manager.bundle.displayName)\"?",
                            isPresented: $confirmDelete,
                            titleVisibility: .visible
                        ) {
                            Button("Delete & Reinstall", role: .destructive) {
                                manager.deleteBundle()
                            }
                            Button("Cancel", role: .cancel) { }
                        } message: {
                            Text("This permanently deletes the VM bundle and all its data. This cannot be undone.")
                        }
                    }
                }
            }
        }
        .padding(48)
    }

    private var bundleSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Name & location
            HStack(spacing: 12) {
                Image(systemName: "externaldrive")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(manager.bundle.displayName)
                        .font(.headline)
                    Text(manager.bundle.abbreviatedPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                HStack(spacing: 6) {
                    Button {
                        manager.selectBundle()
                    } label: {
                        Label("Select VM…", systemImage: "folder")
                    }
                    .help("Open an existing VM bundle")
                    .disabled(manager.isRunning)

                    Button {
                        manager.moveBundle()
                    } label: {
                        Label("Move VM…", systemImage: "arrow.forward")
                    }
                    .help("Move the VM bundle to a new location")
                    .disabled(manager.isRunning || !manager.bundleExists)

                    Button {
                        manager.newVM()
                    } label: {
                        Label("New VM", systemImage: "plus.circle.fill")
                    }
                    .help("Create a new VM bundle")
                    .disabled(manager.isRunning)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            // Shared folders
            sharedFoldersSection
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            // VM settings
            VStack(alignment: .leading, spacing: 8) {
                Text("Hardware Config")
                    .font(.headline)
                HStack(spacing: 8) {
                    Picker("CPU", selection: $manager.vmConfig.cpuCount) {
                        ForEach(VMConfigurationBuilder.availableCPUCounts, id: \.self) { n in
                            Text("\(n) vCPU\(n == 1 ? "" : "s")").tag(n)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    Picker("RAM", selection: $manager.vmConfig.memoryGB) {
                        ForEach(VMConfigurationBuilder.availableMemoryGBOptions, id: \.self) { gb in
                            Text("\(gb) GB").tag(gb)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    Picker("Disk", selection: $manager.vmConfig.diskSizeGB) {
                        ForEach(VMConfig.diskSizeOptions, id: \.self) { gb in
                            Text("\(gb) GB").tag(gb)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .disabled(manager.bundleExists)
                    .help(manager.bundleExists ? "Disk size is fixed after creation" : "Disk image size — cannot be changed after creation")
                    Picker("Network", selection: $manager.vmConfig.bridgedInterfaceID) {
                        Text("NAT only").tag("")
                        if !VMConfigurationBuilder.availableBridgedInterfaces.isEmpty {
                            Divider()
                            ForEach(VMConfigurationBuilder.availableBridgedInterfaces, id: \.identifier) { iface in
                                Text(iface.localizedDisplayName ?? iface.identifier).tag(iface.identifier)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .disabled(manager.isRunning || !VMConfigurationBuilder.hasBridgedNetworkingEntitlement)
                    .help(VMConfigurationBuilder.hasBridgedNetworkingEntitlement
                          ? "NAT only: internet via Mac. Bridged: VM gets its own IP on the selected interface."
                          : "Bridged networking requires the com.apple.vm.networking entitlement — build with 'make build-bridged' after receiving Apple approval.")
                    Picker("Disk Sync", selection: $manager.vmConfig.diskSyncMode) {
                        ForEach(DiskSyncMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .help(manager.vmConfig.diskSyncMode.help)
                }
                .controlSize(.small)
                .disabled(manager.isRunning)

                if VMConfigurationBuilder.isRosettaSupported {
                    Toggle(isOn: $manager.vmConfig.rosettaEnabled) {
                        Label("Rosetta (run x86_64 binaries)", systemImage: "cpu")
                            .font(.caption)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .disabled(manager.isRunning || !VMConfigurationBuilder.isRosettaAvailable)
                    .help(VMConfigurationBuilder.isRosettaAvailable
                          ? "Expose Rosetta to the ARM64 guest so it can run x86_64 binaries"
                          : "Rosetta is not installed — run 'softwareupdate --install-rosetta' in Terminal")
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var sharedFoldersSection: some View {
        DisclosureGroup(isExpanded: $sharedFoldersExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(manager.vmConfig.sharedFolders) { folder in
                            sharedFolderRow(folder)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .frame(maxHeight: 400)
                Button {
                    manager.addSharedFolder()
                } label: {
                    Label(manager.vmConfig.sharedFolders.isEmpty ? "Add Shared Folder…" : "Add Share",
                          systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(manager.isRunning)
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 6) {
                Text("Share Config and Howto")
                    .font(.headline)
                if !manager.vmConfig.sharedFolders.isEmpty {
                    Text("(\(manager.vmConfig.sharedFolders.count))")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func fstabEntry(for folder: SharedFolder) -> String {
        "\(folder.mountTag) /media/\(folder.mountTag) virtiofs defaults 0 0"
    }

    private func mountEntry(for folder: SharedFolder) -> String {
        "sudo mount -t virtiofs \(folder.mountTag) /media/\(folder.mountTag)"
    }

    private func mkdirEntry(for folder: SharedFolder) -> String {
        "sudo mkdir -p /media/\(folder.mountTag)"
    }

    private func inlineCopyButton(_ text: String, tint: Color = .orange) -> some View {
        CopyButton(text: text, tint: tint)
    }

    private func sharedFolderRow(_ folder: SharedFolder) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "folder.badge.gearshape")
                .foregroundStyle(.secondary)
                .font(.caption)
                .frame(width: 14)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                // Host folder path
                HStack(spacing: 4) {
                    Text("Host folder")
                        .font(.system(.caption2))
                        .foregroundStyle(.tertiary)
                        .frame(width: 62, alignment: .leading)
                    Text(folder.path.replacingOccurrences(
                        of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                // Tag
                HStack(spacing: 4) {
                    Text("<tag>")
                        .font(.system(.caption2))
                        .foregroundStyle(.tertiary)
                        .frame(width: 62, alignment: .leading)
                    Text(folder.mountTag)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                commandCard(icon: "terminal",
                            label: "Create mount point first:",
                            command: mkdirEntry(for: folder))
                commandCard(icon: "doc.text",
                            label: "Automount entry in /etc/fstab:",
                            command: fstabEntry(for: folder))
                commandCard(icon: "terminal",
                            label: "Temporary mount:",
                            command: mountEntry(for: folder))
            }

            Spacer()

            VStack(spacing: 6) {
                Button {
                    manager.toggleSharedFolderReadOnly(id: folder.id)
                } label: {
                    Image(systemName: folder.readOnly ? "lock.fill" : "lock.open")
                        .font(.caption)
                        .foregroundStyle(folder.readOnly ? .orange : .secondary)
                }
                .buttonStyle(.borderless)
                .help(folder.readOnly ? "Read-only — click to allow writes" : "Read-write — click to make read-only")
                .disabled(manager.isRunning)

                Button {
                    manager.changeSharedFolder(id: folder.id)
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Change folder")
                .disabled(manager.isRunning)

                Button {
                    manager.removeSharedFolder(id: folder.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove")
                .disabled(manager.isRunning)
            }
        }
        .controlSize(.small)
    }

    private func commandCard(icon: String, label: String, command: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.system(.caption2))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(command)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                CopyButton(text: command, tint: .secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct CopyButton: View {
    let text: String
    var tint: Color = .orange
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            withAnimation { copied = true }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation { copied = false }
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 9))
                .foregroundStyle(copied ? .green : tint)
                .contentTransition(.symbolEffect(.replace.offUp))
        }
        .buttonStyle(.borderless)
        .help(copied ? "Copied!" : "Copy to clipboard")
    }
}

private struct BackgroundView: View {
    @AppStorage("backgroundImagePath") private var backgroundImagePath: String = ""
    @AppStorage("backgroundBlurRadius") private var backgroundBlurRadius: Double = 3

    var body: some View {
        ZStack {
            if !backgroundImagePath.isEmpty, let nsImage = NSImage(contentsOfFile: backgroundImagePath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.25)
                    .blur(radius: backgroundBlurRadius)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.12), Color(.windowBackgroundColor)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}
