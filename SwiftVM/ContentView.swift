import SwiftUI

struct ContentView: View {
    @StateObject private var manager = VirtualMachineManager()

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
                            manager.deleteBundle()
                        }
                        .buttonStyle(.borderless)
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
                sharedFolderRow

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
                    Label("Change…", systemImage: "folder")
                }
                .help("Open an existing VM bundle")
                .disabled(manager.isRunning)

                Button {
                    manager.moveBundle()
                } label: {
                    Label("Move…", systemImage: "arrow.forward")
                }
                .help("Move the VM bundle to a new location")
                .disabled(manager.isRunning || !manager.bundleExists)

                Button {
                    manager.newVM()
                } label: {
                    Label("New…", systemImage: "plus.circle.fill")
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

    private var sharedFolderRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.badge.gearshape")
                .foregroundStyle(.secondary)
                .font(.caption)
            if let path = manager.vmConfig.sharedDirectoryPath {
                Text(path.replacingOccurrences(
                    of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Clear") { manager.clearSharedDirectory() }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .disabled(manager.isRunning)
            } else {
                Button("Add Shared Folder…") { manager.selectSharedDirectory() }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .disabled(manager.isRunning)
                Spacer()
            }
        }
        .controlSize(.small)
    }
}
