import Cocoa
import Virtualization

final class VMWindowController: NSWindowController, NSWindowDelegate {
    private let vmView = VMInputView()
    private var stateObservation: NSKeyValueObservation?

    init(virtualMachine: VZVirtualMachine, displayName: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = displayName
        window.contentMinSize = NSSize(width: 640, height: 480)
        window.contentView = vmView
        super.init(window: window)

        window.delegate = self
        vmView.virtualMachine = virtualMachine
        vmView.automaticallyReconfiguresDisplay = true

        stateObservation = virtualMachine.observe(\.state) { [weak self] vm, _ in
            if vm.state == .stopped || vm.state == .error {
                DispatchQueue.main.async { self?.window?.close() }
            }
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        showWindow(nil)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        window?.makeFirstResponder(vmView)
    }

    func windowDidBecomeMain(_ notification: Notification) {
        window?.makeFirstResponder(vmView)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let vm = vmView.virtualMachine, vm.canStop else { return true }
        vm.stop { _ in }
        return false
    }
}

// Forwards the first click into the VM rather than consuming it to focus the window.
private final class VMInputView: VZVirtualMachineView {
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
