import Foundation
import Virtualization

/// In-process layer-2 hub for the opt-in PROFINET NIC (eth1).
///
/// Apple NAT (`VZNATNetworkDeviceAttachment`) isolates guests from one another, so raw
/// Ethernet traffic such as PROFINET RT (EtherType 0x8892 / DCP) cannot cross between two
/// VMs. Without the restricted `com.apple.vm.networking` entitlement, bridged networking
/// is also unavailable. This hub provides a shared, isolated layer-2 segment using only
/// `VZFileHandleNetworkDeviceAttachment` — no entitlement, no root helper, no physical NIC.
///
/// For each VM that opts in, `makeAttachmentFileHandle(macString:)` creates a
/// `socketpair(AF_UNIX, SOCK_DGRAM)`. One end is handed to the VM's attachment (**one
/// datagram == one Ethernet frame** — the raw frame is passed through unchanged, so no
/// length prefix is involved). The other end is retained here; the hub reads every frame
/// a VM emits and floods it to all *other* connected endpoints. That flooding behaviour
/// is what makes the segment extensible to 3+ VMs (stat173, stat174, …) — a plain
/// socketpair would only connect two.
///
/// Scope: this only connects VMs launched in the **same host process** — i.e. the GUI
/// app's ⌘N windows. The headless CLI runner (one process per VM) and separate app
/// instances cannot share this hub; those would require a cross-process fabric
/// (socket_vmnet or a standalone UNIX-datagram daemon).
final class ProfinetSwitch {
    static let shared = ProfinetSwitch()

    private final class Endpoint {
        let mac: String
        let vmFD: Int32          // handed to the VM's VZFileHandleNetworkDeviceAttachment
        let switchFD: Int32      // hub side of the socketpair
        let source: DispatchSourceRead
        init(mac: String, vmFD: Int32, switchFD: Int32, source: DispatchSourceRead) {
            self.mac = mac
            self.vmFD = vmFD
            self.switchFD = switchFD
            self.source = source
        }
    }

    /// Serial queue guarding `endpoints` and running all read-source event handlers.
    private let queue = DispatchQueue(label: "no.sb21.SwiftVM.ProfinetSwitch")
    private var endpoints: [ObjectIdentifier: Endpoint] = [:]

    /// Socket buffers are grown well beyond the tiny defaults; bursty RT traffic will
    /// silently drop frames otherwise. ~4 MB on both ends of every socket.
    private static let socketBufferBytes: Int32 = 4 * 1024 * 1024
    /// Large enough for any single Ethernet frame (jumbo included).
    private static let frameBufferBytes = 65_536

    private init() {}

    /// Create a new endpoint on the shared segment and return the `FileHandle` to pass to
    /// `VZFileHandleNetworkDeviceAttachment`. Returns `nil` if the socketpair can't be
    /// created. Any existing endpoint reusing `macString` (e.g. a VM being restarted) is
    /// torn down first so file descriptors don't accumulate.
    func makeAttachmentFileHandle(macString: String) -> FileHandle? {
        var fds: [Int32] = [0, 0]
        let rc = fds.withUnsafeMutableBufferPointer { ptr in
            socketpair(AF_UNIX, SOCK_DGRAM, 0, ptr.baseAddress)
        }
        guard rc == 0 else {
            perror("ProfinetSwitch: socketpair")
            return nil
        }
        let vmFD = fds[0]
        let switchFD = fds[1]

        Self.growBuffers(fd: vmFD)
        Self.growBuffers(fd: switchFD)
        // Non-blocking hub side so the drain loop terminates on EAGAIN and a congested
        // peer never stalls the whole segment (the frame is dropped instead).
        Self.setNonBlocking(fd: switchFD)

        let source = DispatchSource.makeReadSource(fileDescriptor: switchFD, queue: queue)
        let endpoint = Endpoint(mac: macString, vmFD: vmFD, switchFD: switchFD, source: source)
        let key = ObjectIdentifier(endpoint)

        source.setEventHandler { [weak self, weak endpoint] in
            guard let self, let endpoint else { return }
            self.forwardFrames(from: endpoint)
        }
        source.setCancelHandler {
            close(switchFD)
            close(vmFD)
        }

        queue.sync {
            for (existingKey, ep) in endpoints where ep.mac == macString {
                ep.source.cancel()
                endpoints.removeValue(forKey: existingKey)
            }
            endpoints[key] = endpoint
        }
        source.resume()

        // closeOnDealloc:false — the fd lifetime is owned by the hub (closed in the source's
        // cancel handler), not by this FileHandle, so ARC can't yank it from under the VM.
        return FileHandle(fileDescriptor: vmFD, closeOnDealloc: false)
    }

    // MARK: - Frame forwarding (runs on `queue`)

    private func forwardFrames(from origin: Endpoint) {
        var buffer = [UInt8](repeating: 0, count: Self.frameBufferBytes)
        while true {
            let n = buffer.withUnsafeMutableBytes { raw in
                recv(origin.switchFD, raw.baseAddress, raw.count, 0)
            }
            if n <= 0 { break }  // EAGAIN/EWOULDBLOCK: no more frames queued right now
            // Flood the frame verbatim to every other endpoint — one datagram stays one
            // Ethernet frame end to end.
            for (_, ep) in endpoints where ep !== origin {
                _ = buffer.withUnsafeBytes { raw in
                    send(ep.switchFD, raw.baseAddress, n, 0)
                }
            }
        }
    }

    // MARK: - Socket tuning

    private static func growBuffers(fd: Int32) {
        var size = socketBufferBytes
        let len = socklen_t(MemoryLayout<Int32>.size)
        if setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &size, len) != 0 {
            perror("ProfinetSwitch: SO_SNDBUF")
        }
        if setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &size, len) != 0 {
            perror("ProfinetSwitch: SO_RCVBUF")
        }
    }

    private static func setNonBlocking(fd: Int32) {
        let flags = fcntl(fd, F_GETFL, 0)
        if flags >= 0 {
            _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        }
    }
}
