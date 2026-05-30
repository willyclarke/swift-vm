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
                    icon: "folder.badge.gearshape", color: .indigo,
                    title: "Folder Sharing",
                    rows: [
                        ("Add folder",    "Click **Add Shared Folder…** in the VM card. Multiple folders are supported. Each folder gets a unique mount tag (derived from the folder name) shown in small text below its path — use that tag in the mount commands below."),
                        ("RO / RW",       "Click the lock icon on a folder row to toggle between read-write (open lock) and read-only (closed lock, shown in orange)."),
                        ("Change",        "Click the pencil icon to pick a different host folder while keeping the same mount tag and settings."),
                        ("!",             "The tag shown in small text below each folder path in the VM card is the **only link** between SwiftVM and the guest. It must match exactly in every command. For example, if the VM card shows `downloads`, every `<tag>` below becomes `downloads`."),
                        ("Mount point",   "Create the mount point inside the guest (replace `<tag>` with the tag shown in the VM card):"),
                        ("",              "`sudo mkdir -p /media/<tag>`"),
                        ("Void Linux",    "The `virtiofs` module ships with the standard `linux` package — no separate install needed. Load it:"),
                        ("",              "`sudo modprobe virtiofs`"),
                        ("",              "Auto-load on boot:"),
                        ("",              "`echo virtiofs | sudo tee /etc/modules-load.d/virtiofs.conf`"),
                        ("",              "Mount the share:"),
                        ("",              "`sudo mount -t virtiofs <tag> /media/<tag>`"),
                        ("Ubuntu 24.04",  "The `virtiofs` module ships with the Ubuntu kernel — no install needed. Mount with:"),
                        ("",              "`sudo mount -t virtiofs <tag> /media/<tag>`"),
                        ("Auto-mount",    "Append one line per shared folder to `/etc/fstab` — the format is the same on Void Linux and Ubuntu:"),
                        ("",              "`<tag>  /media/<tag>  virtiofs  defaults  0  0`"),
                        ("",              "Then run `sudo mount -a` to mount without rebooting."),
                        ("Permissions",   "Files are owned by the user that started SwiftVM on the host. Use the lock toggle to restrict a folder to read-only inside the guest."),
                    ]
                )

                helpSection(
                    icon: "cpu", color: .blue,
                    title: "Rosetta — Run x86_64 Binaries",
                    rows: [
                        ("What it does",  "Rosetta lets the ARM64 guest transparently execute x86_64 ELF binaries — compilers, build tools, `docker build --platform linux/amd64`, and more. Enable the **Rosetta** checkbox in the VM card, then restart the VM."),
                        ("!",             "The Rosetta tag is always `rosetta`. Use it exactly as shown in all commands below."),
                        ("Requires",      "Rosetta must be installed on the Mac. If the checkbox is greyed out, run this in macOS Terminal:"),
                        ("",              "`softwareupdate --install-rosetta`"),
                        ("Mount point",   "Create the mount point inside the guest:"),
                        ("",              "`sudo mkdir -p /media/rosetta`"),
                        ("fstab",         "Add to `/etc/fstab` (must be read-only):"),
                        ("",              "`rosetta  /media/rosetta  virtiofs  ro  0  0`"),
                        ("",              "Then apply: `sudo mount -a`"),
                        ("Register",      "Load `binfmt_misc` and mount it:"),
                        ("",              "`sudo modprobe binfmt_misc`"),
                        ("",              "`sudo mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc`"),
                        ("",              "Register Rosetta as the x86_64 ELF handler using `sudo sh -c` to avoid pipe/sudo issues:"),
                        ("",              "`sudo sh -c 'echo \":rosetta:M::\\x7fELF\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x3e\\x00:\\xff\\xff\\xff\\xff\\xff\\xfe\\xfe\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff:/media/rosetta/rosetta:CF\" > /proc/sys/fs/binfmt_misc/register'`"),
                        ("Void Linux",    "For persistence on Void, add to `/etc/rc.local` (create it if missing):"),
                        ("",              "`sudo sh -c 'echo \":rosetta:M::\\x7fELF\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x3e\\x00:\\xff\\xff\\xff\\xff\\xff\\xfe\\xfe\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff:/media/rosetta/rosetta:CF\" > /proc/sys/fs/binfmt_misc/register' >> /etc/rc.local`"),
                        ("",              "`sudo chmod +x /etc/rc.local`"),
                        ("Ubuntu",        "On Ubuntu, use `update-binfmts` for persistence across reboots:"),
                        ("",              "`sudo apt install -y binfmt-support`"),
                        ("",              "`sudo update-binfmts --install rosetta /media/rosetta/rosetta --magic \"\\x7fELF\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x3e\\x00\" --mask \"\\xff\\xff\\xff\\xff\\xff\\xfe\\xfe\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff\" --credentials yes --preserve no --fix-binary yes`"),
                        ("Verify",        "Confirm Rosetta is registered:"),
                        ("",              "`cat /proc/sys/fs/binfmt_misc/rosetta`"),
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
                    if row.0 == "!" {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "link")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                                .padding(.top, 1)
                            Text(.init(row.1))
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 6))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            Text(row.0)
                                .font(.subheadline.bold())
                                .frame(width: 110, alignment: .leading)
                                .padding(.vertical, 7)
                            if row.0.isEmpty {
                                HStack(spacing: 6) {
                                    Text(.init(row.1))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Button {
                                        let raw = row.1.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(raw, forType: .string)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Copy to clipboard")
                                }
                                .padding(.vertical, 5)
                            } else {
                                Text(.init(row.1))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 7)
                            }
                        }
                        .padding(.horizontal, 12)
                        .background(index % 2 == 0 ? Color.clear : Color.primary.opacity(0.03))
                    }
                }
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
