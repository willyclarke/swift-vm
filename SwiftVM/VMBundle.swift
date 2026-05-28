import Foundation

struct VMBundle {
    let url: URL

    init(name: String = "Linux VM") {
        url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("\(name).bundle")
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    var diskImageURL: URL        { url.appendingPathComponent("Disk.img") }
    var nvramURL: URL            { url.appendingPathComponent("NVRAM") }
    var machineIdentifierURL: URL { url.appendingPathComponent("MachineIdentifier") }
    var macAddressURL: URL       { url.appendingPathComponent("MACAddress") }

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
