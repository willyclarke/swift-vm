import Foundation

struct VMConfig: Codable {
    var cpuCount: Int
    var memoryGB: Int
}

struct VMBundle {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(name: String = "Linux VM") {
        self.init(url: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("\(name).bundle"))
    }

    var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }

    var abbreviatedPath: String {
        url.path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    var diskImageURL: URL         { url.appendingPathComponent("Disk.img") }
    var nvramURL: URL             { url.appendingPathComponent("NVRAM") }
    var machineIdentifierURL: URL { url.appendingPathComponent("MachineIdentifier") }
    var macAddressURL: URL        { url.appendingPathComponent("MACAddress") }
    var configURL: URL            { url.appendingPathComponent("Config.json") }

    func loadConfig() -> VMConfig {
        if let data = try? Data(contentsOf: configURL),
           let config = try? JSONDecoder().decode(VMConfig.self, from: data) {
            return config
        }
        return VMConfig(
            cpuCount: max(1, ProcessInfo.processInfo.processorCount - 1),
            memoryGB: 4
        )
    }

    func saveConfig(_ config: VMConfig) throws {
        let data = try JSONEncoder().encode(config)
        try data.write(to: configURL, options: .atomic)
    }

    func create() throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        FileManager.default.createFile(atPath: diskImageURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: diskImageURL)
        // APFS creates sparse files, so this returns immediately regardless of size.
        let diskSize: UInt64 = 64 * 1_024 * 1_024 * 1_024
        try handle.truncate(atOffset: diskSize)
        try handle.close()
    }

    func delete() throws {
        try FileManager.default.removeItem(at: url)
    }
}
