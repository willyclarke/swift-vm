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
}
