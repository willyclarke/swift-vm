import Virtualization
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class VirtualMachineManager: NSObject, ObservableObject, VZVirtualMachineDelegate {
    @Published var isRunning = false
    @Published var isStarting = false
    @Published var hasError = false
    @Published var errorMessage: String?
    @Published var bundle: VMBundle {
        didSet {
            Self.saveBookmark(for: bundle.url)
            vmConfig = bundle.loadConfig()
        }
    }
    @Published var vmConfig: VMConfig {
        didSet {
            guard bundle.exists else { return }
            try? bundle.saveConfig(vmConfig)
        }
    }

    private var virtualMachine: VZVirtualMachine?
    private var windowController: VMWindowController?

    // "bundleURL" key kept for migration from older builds only.
    private static let bundleBookmarkKey = "bundleBookmark"
    private static let bundleURLKey = "bundleURL"

    override init() {
        let b: VMBundle
        if let data = UserDefaults.standard.data(forKey: Self.bundleBookmarkKey),
           let url = Self.resolveBookmark(data) {
            b = VMBundle(url: url)
        } else if let path = UserDefaults.standard.string(forKey: Self.bundleURLKey) {
            b = VMBundle(url: URL(fileURLWithPath: path))
        } else {
            b = VMBundle()
        }
        bundle = b
        vmConfig = b.loadConfig()
        super.init()
        // Migrate path → bookmark, or refresh on first launch.
        if b.exists {
            Self.saveBookmark(for: b.url)
            UserDefaults.standard.removeObject(forKey: Self.bundleURLKey)
        }
    }

    // MARK: - Bookmark helpers

    private static func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: [], includingResourceValuesForKeys: nil, relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: bundleBookmarkKey)
    }

    private static func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale
        ) else { return nil }
        if isStale { saveBookmark(for: url) }
        return url
    }

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

    func selectBundle() {
        let panel = NSOpenPanel()
        panel.title = "Select VM Bundle"
        panel.message = "Choose an existing .bundle directory."
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.bundle = VMBundle(url: url)
        }
    }

    func moveBundle() {
        let panel = NSSavePanel()
        panel.title = "Move VM Bundle"
        panel.message = "Choose a new name and location for \"\(bundle.displayName)\"."
        panel.nameFieldStringValue = bundle.url.lastPathComponent
        panel.directoryURL = bundle.url.deletingLastPathComponent()
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard let self, response == .OK, var url = panel.url else { return }
            if url.pathExtension.lowercased() != "bundle" {
                url = url.appendingPathExtension("bundle")
            }
            do {
                try FileManager.default.moveItem(at: self.bundle.url, to: url)
                self.bundle = VMBundle(url: url)
            } catch {
                self.showError(error)
            }
        }
    }

    func newVM() {
        let panel = NSSavePanel()
        panel.title = "New Virtual Machine"
        panel.message = "Choose a name and location for the new VM bundle."
        panel.nameFieldStringValue = "Linux VM.bundle"
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard let self, response == .OK, var url = panel.url else { return }
            if url.pathExtension.lowercased() != "bundle" {
                url = url.appendingPathExtension("bundle")
            }
            self.bundle = VMBundle(url: url)
            self.promptForISO()
        }
    }

    // MARK: - Private

    private func promptForISO() {
        let panel = NSOpenPanel()
        panel.title = "Select Linux ISO Image"
        panel.message = "Choose a Linux ISO for your Mac's architecture (\(hostArch))."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.install(isoURL: url)
        }
    }

    private func install(isoURL: URL) {
        isStarting = true
        do {
            try bundle.create()
            Self.saveBookmark(for: bundle.url)
            try bundle.saveConfig(vmConfig)
            let config = try VMConfigurationBuilder.build(bundle: bundle, installISO: isoURL, vmConfig: vmConfig)
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
            let config = try VMConfigurationBuilder.build(bundle: bundle, installISO: nil, vmConfig: vmConfig)
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

        let wc = VMWindowController(virtualMachine: vm, displayName: bundle.displayName)
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
            self.windowController?.window?.close()
            self.virtualMachine = nil
            self.windowController = nil
            self.isRunning = false
        }
    }

    nonisolated func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        MainActor.assumeIsolated {
            self.windowController?.window?.close()
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
