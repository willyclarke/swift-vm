import Foundation
import Virtualization

// Headless VM runner — no window, interact via SSH.
// Usage: run.sh [bundle-name]   (default: "Linux VM")

let bundleName = CommandLine.arguments.count > 1
    ? CommandLine.arguments.dropFirst().joined(separator: " ")
    : "Linux VM"

let bundleURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("\(bundleName).bundle")

guard FileManager.default.fileExists(atPath: bundleURL.path) else {
    fputs("Error: '\(bundleURL.path)' not found.\n", stderr)
    fputs("Run SwiftVM.app first to install the OS.\n", stderr)
    exit(1)
}

// MARK: - Configuration

func buildConfiguration() throws -> VZVirtualMachineConfiguration {
    let config = VZVirtualMachineConfiguration()

    let total = ProcessInfo.processInfo.processorCount
    config.cpuCount = min(max(max(1, total - 1),
                              VZVirtualMachineConfiguration.minimumAllowedCPUCount),
                          VZVirtualMachineConfiguration.maximumAllowedCPUCount)
    let mem: UInt64 = 4 * 1_024 * 1_024 * 1_024
    config.memorySize = min(max(mem, VZVirtualMachineConfiguration.minimumAllowedMemorySize),
                            VZVirtualMachineConfiguration.maximumAllowedMemorySize)

    let idData = try Data(contentsOf: bundleURL.appendingPathComponent("MachineIdentifier"))
    guard let machineId = VZGenericMachineIdentifier(dataRepresentation: idData) else {
        throw NSError(domain: "SwiftVM", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Invalid machine identifier"])
    }
    let platform = VZGenericPlatformConfiguration()
    platform.machineIdentifier = machineId
    config.platform = platform

    let bootloader = VZEFIBootLoader()
    bootloader.variableStore = VZEFIVariableStore(url: bundleURL.appendingPathComponent("NVRAM"))
    config.bootLoader = bootloader

    let diskAttachment = try VZDiskImageStorageDeviceAttachment(
        url: bundleURL.appendingPathComponent("Disk.img"), readOnly: false)
    config.storageDevices = [VZVirtioBlockDeviceConfiguration(attachment: diskAttachment)]

    let network = VZVirtioNetworkDeviceConfiguration()
    network.attachment = VZNATNetworkDeviceAttachment()
    let macURL = bundleURL.appendingPathComponent("MACAddress")
    if let saved = try? String(contentsOf: macURL, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines),
       let mac = VZMACAddress(string: saved) {
        network.macAddress = mac
    }
    config.networkDevices = [network]

    try config.validate()
    return config
}

// MARK: - Delegate

final class VMDelegate: NSObject, VZVirtualMachineDelegate {
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        print("VM stopped.")
        exit(0)
    }
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        fputs("VM stopped with error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

// MARK: - Start

let config: VZVirtualMachineConfiguration
do {
    config = try buildConfiguration()
} catch {
    fputs("Configuration error: \(error.localizedDescription)\n", stderr)
    exit(1)
}

let delegate = VMDelegate()
let vm = VZVirtualMachine(configuration: config)
vm.delegate = delegate

let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigintSource.setEventHandler {
    print("\nStopping VM…")
    vm.stop { _ in exit(0) }
}
sigintSource.resume()
signal(SIGINT, SIG_IGN)

print("Starting \"\(bundleName)\"…")
vm.start { result in
    switch result {
    case .success:
        print("VM running — connect via SSH. Press Ctrl+C to stop.")
    case .failure(let error):
        fputs("Failed to start: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

RunLoop.main.run()
