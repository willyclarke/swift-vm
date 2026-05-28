import Virtualization

enum VMConfigurationBuilder {

    /// Build a complete `VZVirtualMachineConfiguration`.
    /// Pass a non-nil `installISO` for a first-time install; pass `nil` to boot an existing image.
    static func build(bundle: VMBundle, installISO: URL?) throws -> VZVirtualMachineConfiguration {
        let config = VZVirtualMachineConfiguration()
        config.cpuCount = cpuCount()
        config.memorySize = memorySize()

        let platform = VZGenericPlatformConfiguration()
        let bootloader = VZEFIBootLoader()

        if let isoURL = installISO {
            platform.machineIdentifier = try createMachineIdentifier(savingTo: bundle.machineIdentifierURL)
            bootloader.variableStore = try VZEFIVariableStore(creatingVariableStoreAt: bundle.nvramURL)
            config.storageDevices = [
                try usbMassStorage(isoURL: isoURL),
                try mainDisk(url: bundle.diskImageURL),
            ]
        } else {
            platform.machineIdentifier = try loadMachineIdentifier(from: bundle.machineIdentifierURL)
            bootloader.variableStore = VZEFIVariableStore(url: bundle.nvramURL)
            config.storageDevices = [
                try mainDisk(url: bundle.diskImageURL),
            ]
        }

        config.platform = platform
        config.bootLoader = bootloader
        config.networkDevices = [try natNetwork(bundle: bundle)]
        config.graphicsDevices = [virtioGraphics()]
        config.audioDevices = [audioInput(), audioOutput()]
        config.keyboards = [VZUSBKeyboardConfiguration()]
        config.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        config.consoleDevices = [spiceAgentConsole()]

        try config.validate()
        return config
    }

    // MARK: - Platform

    private static func createMachineIdentifier(savingTo url: URL) throws -> VZGenericMachineIdentifier {
        let id = VZGenericMachineIdentifier()
        try id.dataRepresentation.write(to: url)
        return id
    }

    private static func loadMachineIdentifier(from url: URL) throws -> VZGenericMachineIdentifier {
        let data = try Data(contentsOf: url)
        guard let id = VZGenericMachineIdentifier(dataRepresentation: data) else {
            throw VMError.invalidMachineIdentifier
        }
        return id
    }

    // MARK: - Storage

    private static func mainDisk(url: URL) throws -> VZVirtioBlockDeviceConfiguration {
        let attachment = try VZDiskImageStorageDeviceAttachment(url: url, readOnly: false)
        return VZVirtioBlockDeviceConfiguration(attachment: attachment)
    }

    private static func usbMassStorage(isoURL: URL) throws -> VZUSBMassStorageDeviceConfiguration {
        let attachment = try VZDiskImageStorageDeviceAttachment(url: isoURL, readOnly: true)
        return VZUSBMassStorageDeviceConfiguration(attachment: attachment)
    }

    // MARK: - Network

    private static func natNetwork(bundle: VMBundle) throws -> VZVirtioNetworkDeviceConfiguration {
        let device = VZVirtioNetworkDeviceConfiguration()
        device.attachment = VZNATNetworkDeviceAttachment()
        device.macAddress = try loadOrCreateMACAddress(bundle: bundle)
        return device
    }

    private static func loadOrCreateMACAddress(bundle: VMBundle) throws -> VZMACAddress {
        if FileManager.default.fileExists(atPath: bundle.macAddressURL.path),
           let saved = try? String(contentsOf: bundle.macAddressURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           let mac = VZMACAddress(string: saved) {
            return mac
        }
        let mac = VZMACAddress.randomLocallyAdministered()
        try mac.string.write(to: bundle.macAddressURL, atomically: true, encoding: .utf8)
        return mac
    }

    // MARK: - Graphics

    private static func virtioGraphics() -> VZVirtioGraphicsDeviceConfiguration {
        let device = VZVirtioGraphicsDeviceConfiguration()
        device.scanouts = [VZVirtioGraphicsScanoutConfiguration(widthInPixels: 1280, heightInPixels: 720)]
        return device
    }

    // MARK: - Audio

    private static func audioInput() -> VZVirtioSoundDeviceConfiguration {
        let device = VZVirtioSoundDeviceConfiguration()
        let stream = VZVirtioSoundDeviceInputStreamConfiguration()
        stream.source = VZHostAudioInputStreamSource()
        device.streams = [stream]
        return device
    }

    private static func audioOutput() -> VZVirtioSoundDeviceConfiguration {
        let device = VZVirtioSoundDeviceConfiguration()
        let stream = VZVirtioSoundDeviceOutputStreamConfiguration()
        stream.sink = VZHostAudioOutputStreamSink()
        device.streams = [stream]
        return device
    }

    // MARK: - Console / Clipboard sharing

    private static func spiceAgentConsole() -> VZVirtioConsoleDeviceConfiguration {
        let device = VZVirtioConsoleDeviceConfiguration()
        let port = VZVirtioConsolePortConfiguration()
        port.name = VZSpiceAgentPortAttachment.spiceAgentPortName
        port.attachment = VZSpiceAgentPortAttachment()
        device.ports[0] = port
        return device
    }

    // MARK: - Resource sizing

    private static func cpuCount() -> Int {
        let total = ProcessInfo.processInfo.processorCount
        let count = max(1, total - 1)
        return min(max(count, VZVirtualMachineConfiguration.minimumAllowedCPUCount),
                   VZVirtualMachineConfiguration.maximumAllowedCPUCount)
    }

    private static func memorySize() -> UInt64 {
        let size: UInt64 = 4 * 1_024 * 1_024 * 1_024
        return min(max(size, VZVirtualMachineConfiguration.minimumAllowedMemorySize),
                   VZVirtualMachineConfiguration.maximumAllowedMemorySize)
    }
}

enum VMError: LocalizedError {
    case invalidMachineIdentifier

    var errorDescription: String? {
        "Failed to decode the VM machine identifier from disk."
    }
}
