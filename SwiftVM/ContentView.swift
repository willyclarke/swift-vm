import SwiftUI

struct ContentView: View {
    @StateObject private var manager = VirtualMachineManager()
    @State private var confirmDelete = false

    var body: some View {
        launchView
            .frame(minWidth: 400, minHeight: 300)
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
                    Button(manager.bundleExists ? "Start Virtual Machine" : "Install Linux…") {
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
                Divider()
                sharedFoldersSection

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
                }
                .controlSize(.small)
                .disabled(manager.isRunning)
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
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var sharedFoldersSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(manager.vmConfig.sharedFolders) { folder in
                sharedFolderRow(folder)
            }
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
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 9))
                .foregroundStyle(tint)
        }
        .buttonStyle(.borderless)
        .help("Copy to clipboard")
    }

    private func sharedFolderRow(_ folder: SharedFolder) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "folder.badge.gearshape")
                .foregroundStyle(.secondary)
                .font(.caption)
                .frame(width: 14)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
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

                // mkdir sticker
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("Create mount point first:")
                            .font(.system(.caption2))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Text(mkdirEntry(for: folder))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                        inlineCopyButton(mkdirEntry(for: folder), tint: .secondary)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))

                // fstab automount hint
                commandHint(
                    label: "Automount entry in /etc/fstab:",
                    command: fstabEntry(for: folder)
                )

                // Temporary mount hint
                commandHint(
                    label: "Temporary mount:",
                    command: mountEntry(for: folder)
                )
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

    private func commandHint(label: String, command: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.system(.caption2))
                    .foregroundStyle(.primary)
            }
            HStack(spacing: 4) {
                Text(command)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
                inlineCopyButton(command)
            }
        }
    }
}
