import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                appHeader

                helpSection(
                    icon: "plus.circle.fill", color: .blue,
                    title: "Creating a Virtual Machine",
                    rows: [
                        ("New…",          "Choose a name and location for a new VM bundle."),
                        ("Select ISO",    "Pick a Linux ISO matching your Mac's CPU — ARM64 (aarch64) on Apple Silicon, x86_64 on Intel."),
                        ("Configure",     "Set CPU cores and memory with the dropdowns before installing."),
                        ("Install",       "Click **Install Linux…** and follow the guest OS installer. The VM window opens automatically."),
                    ]
                )

                helpSection(
                    icon: "externaldrive.fill", color: .orange,
                    title: "VM Bundles",
                    rows: [
                        ("Change…",       "Switch to an existing `.bundle` directory on disk."),
                        ("Move…",         "Relocate the bundle to a new path — the app's bookmark updates automatically."),
                        ("Finder moves",  "Bundles moved or renamed in Finder are found automatically on next launch via file bookmarks."),
                        ("Delete",        "**Delete & Reinstall** permanently removes the bundle and all VM data."),
                    ]
                )

                helpSection(
                    icon: "slider.horizontal.3", color: .purple,
                    title: "CPU & Memory",
                    rows: [
                        ("CPU",           "Defaults to host core count minus one. Configurable per VM via the dropdown."),
                        ("Memory",        "Defaults to 4 GB. Configurable per VM via the dropdown."),
                        ("Saved",         "Settings are stored in `Config.json` inside the bundle and applied on next boot."),
                    ]
                )

                helpSection(
                    icon: "terminal.fill", color: .green,
                    title: "Headless / SSH Mode",
                    rows: [
                        ("CLI runner",    "Run `./scripts/void-linux/run.sh` to start a VM without a display window."),
                        ("SSH",           "Connect with `ssh user@<ip>`. The VM's IP is shown by `ip addr show eth0` inside the guest."),
                        ("Stable IP",     "The MAC address is fixed per bundle so the VM gets the same DHCP lease each boot."),
                        ("Stop",          "Press **Ctrl+C** in the terminal to stop the VM gracefully."),
                    ]
                )

                helpSection(
                    icon: "keyboard", color: .gray,
                    title: "Shortcuts",
                    rows: [
                        ("⌘ ↩",          "Start or install the current VM."),
                        ("⌘ ?",          "Open this help window."),
                        ("Ctrl+C",        "Stop the VM (CLI / headless mode)."),
                    ]
                )

                helpSection(
                    icon: "puzzlepiece.extension.fill", color: .teal,
                    title: "Guest OS Setup",
                    rows: [
                        ("Void Linux",    "Use the manual chroot install — `void-installer` is not included in the live ISO."),
                        ("Kernel",        "`base-system` does **not** pull in the kernel. Run `xbps-install linux` explicitly inside the chroot."),
                        ("Post-install",  "Run `postinstall/void-linux/postinstall.sh` after first boot to set up XFCE, audio, and clipboard sharing."),
                        ("Ubuntu",        "ARM64 server ISOs available at cdimage.ubuntu.com/releases/."),
                    ]
                )
            }
            .padding(28)
        }
        .frame(minWidth: 560, minHeight: 500)
    }

    // MARK: - Header

    private var appHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("SwiftVM")
                    .font(.title.bold())
                Text("macOS virtual machines using Apple's Virtualization framework.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Section builder

    private func helpSection(
        icon: String,
        color: Color,
        title: String,
        rows: [(String, String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .top, spacing: 12) {
                        Text(row.0)
                            .font(.subheadline.bold())
                            .frame(width: 110, alignment: .leading)
                            .padding(.vertical, 7)
                        Text(.init(row.1))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 7)
                    }
                    .padding(.horizontal, 12)
                    .background(index % 2 == 0 ? Color.clear : Color.primary.opacity(0.03))
                }
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
