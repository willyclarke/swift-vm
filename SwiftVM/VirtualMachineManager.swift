import Virtualization
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class VirtualMachineManager: NSObject, ObservableObject, VZVirtualMachineDelegate {
    @Published var isRunning = false
    @Published var isStarting = false
    @Published var hasError = false
    @Published var errorMessage: String?

    private let bundle = VMBundle()
    private var virtualMachine: VZVirtualMachine?
    private var windowController: VMWindowController?

    var bundleExists: Bool { bundle.exists }

    // MARK: - Public

    func start() {
        if bundle.exists {
            boot()
        } else {
            promptForISO()
        }
    }

    func deleteBundle() {
        try? bundle.delete()
    }

    // MARK: - Private

    private func promptForISO() {
        let panel = NSOpenPanel()
        panel.title = "Select Linux ISO Image"
        panel.message = "Choose a Linux ISO for your Mac's architecture (\(hostArch))."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let isoType = UTType(filenameExtension: "iso") {
            panel.allowedContentTypes = [isoType]
        }

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.install(isoURL: url)
        }
    }

    private func install(isoURL: URL) {
        isStarting = true
        do {
            try bundle.create()
            let config = try VMConfigurationBuilder.build(bundle: bundle, installISO: isoURL)
            launch(configuration: config)
        } catch {
            isStarting = false
            try? bundle.delete()
            showError(error)
        }
    }

    private func boot() {
        isStarting = true
        do {
            let config = try VMConfigurationBuilder.build(bundle: bundle, installISO: nil)
            launch(configuration: config)
        } catch {
            isStarting = false
            showError(error)
        }
    }

    private func launch(configuration: VZVirtualMachineConfiguration) {
        let vm = VZVirtualMachine(configuration: configuration)
        vm.delegate = self
        virtualMachine = vm

        let wc = VMWindowController(virtualMachine: vm)
        windowController = wc
        wc.show()

        vm.start { [weak self] result in
            guard let self else { return }
            self.isStarting = false
            if case .failure(let error) = result {
                self.virtualMachine = nil
                self.windowController = nil
                self.showError(error)
            } else {
                self.isRunning = true
            }
        }
    }

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        hasError = true
    }

    private var hostArch: String {
        #if arch(arm64)
        return "ARM64 — download aarch64 ISO"
        #else
        return "x86_64 — download amd64 ISO"
        #endif
    }

    // MARK: - VZVirtualMachineDelegate
    // Apple guarantees these callbacks arrive on the main queue.

    nonisolated func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        MainActor.assumeIsolated {
            self.virtualMachine = nil
            self.windowController = nil
            self.isRunning = false
        }
    }

    nonisolated func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        MainActor.assumeIsolated {
            self.virtualMachine = nil
            self.windowController = nil
            self.isRunning = false
            self.showError(error)
        }
    }

    nonisolated func virtualMachine(
        _ virtualMachine: VZVirtualMachine,
        networkDevice: VZNetworkDevice,
        attachmentWasDisconnectedWithError error: Error
    ) {
        print("Network attachment disconnected: \(error.localizedDescription)")
    }
}
