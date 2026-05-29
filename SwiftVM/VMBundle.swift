import Foundation

struct SharedFolder: Codable, Identifiable {
    var id: UUID
    var path: String
    var readOnly: Bool
    var mountTag: String

    init(url: URL, readOnly: Bool = false, existingTags: [String] = []) {
        self.id = UUID()
        self.path = url.path
        self.readOnly = readOnly
        self.mountTag = Self.makeTag(for: url, avoiding: existingTags)
    }

    static func makeTag(for url: URL, avoiding existing: [String]) -> String {
        var sanitized = ""
        for ch in url.lastPathComponent.lowercased() {
            if ch.isLetter || ch.isNumber {
                sanitized.append(ch)
            } else if !sanitized.isEmpty && sanitized.last != "-" {
                sanitized.append("-")
            }
        }
        sanitized = String(
            sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "-")).prefix(36))
        let base = sanitized.isEmpty ? "share" : sanitized
        var tag = base
        var i = 1
        while existing.contains(tag) {
            tag = "\(base)-\(i)"
            i += 1
        }
        return tag
    }
}

struct VMConfig: Codable {
    var cpuCount: Int
    var memoryGB: Int
    var sharedFolders: [SharedFolder]

    var diskSizeGB: Int
    var rosettaEnabled: Bool

    init(cpuCount: Int, memoryGB: Int, diskSizeGB: Int = 64,
         rosettaEnabled: Bool = false, sharedFolders: [SharedFolder] = []) {
        self.cpuCount = cpuCount
        self.memoryGB = memoryGB
        self.diskSizeGB = diskSizeGB
        self.rosettaEnabled = rosettaEnabled
        self.sharedFolders = sharedFolders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cpuCount = try c.decode(Int.self, forKey: .cpuCount)
        memoryGB = try c.decode(Int.self, forKey: .memoryGB)
        diskSizeGB = (try? c.decode(Int.self, forKey: .diskSizeGB)) ?? 64
        rosettaEnabled = (try? c.decode(Bool.self, forKey: .rosettaEnabled)) ?? false
        sharedFolders = (try? c.decode([SharedFolder].self, forKey: .sharedFolders)) ?? []
    }

    static let diskSizeOptions: [Int] = [32, 64, 128, 256, 512]
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

    func create(config: VMConfig) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        FileManager.default.createFile(atPath: diskImageURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: diskImageURL)
        // APFS creates sparse files, so this returns immediately regardless of size.
        let diskSize: UInt64 = UInt64(config.diskSizeGB) * 1_024 * 1_024 * 1_024
        try handle.truncate(atOffset: diskSize)
        try handle.close()
    }

    func delete() throws {
        try FileManager.default.removeItem(at: url)
    }
}
