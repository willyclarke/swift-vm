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

            VStack(alignment: .leading, spacing: 2) {
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
                    Label("Change…", systemImage: "folder")
                }
                .help("Open an existing VM bundle")
                .disabled(manager.isRunning)

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
}
