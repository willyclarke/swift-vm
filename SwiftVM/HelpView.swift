import SwiftUI

/// One topic in the Howto window — drives both the sidebar row and the detail pane.
private struct HelpTopic: Identifiable {
    var id: String { title }
    let icon: String
    let color: Color
    let title: String
    let rows: [(String, String)]
}

struct HelpView: View {
    @State private var selection: HelpTopic.ID?

    var body: some View {
        NavigationSplitView {
            List(topics, selection: $selection) { topic in
                Label(topic.title, systemImage: topic.icon)
                    .foregroundStyle(topic.color)
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
            .navigationTitle("Howto")
        } detail: {
            if let selection, let topic = topics.first(where: { $0.id == selection }) {
                ScrollView {
                    topicDetail(topic)
                        .padding(24)
                }
            } else {
                welcome
            }
        }
        .frame(minWidth: 760, minHeight: 540)
    }

    // MARK: - Welcome (no selection)

    private var welcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
            Text("SwiftVM")
                .font(.largeTitle.bold())
            Text("macOS virtual machines using Apple's Virtualization framework.")
                .foregroundStyle(.secondary)
            Text("Choose a topic in the sidebar to get started.")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Topic detail

    private func topicDetail(_ topic: HelpTopic) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(topic.title, systemImage: topic.icon)
                .font(.title2.bold())
                .foregroundStyle(topic.color)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(topic.rows.enumerated()), id: \.offset) { index, row in
                    rowView(row, index: index)
                }
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(topic.color.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Row builder

    @ViewBuilder
    private func rowView(_ row: (String, String), index: Int) -> some View {
        if row.0 == "!" {
            calloutRow(row.1)
        } else if row.0.isEmpty {
            codeRow(row.1)
                .background(index % 2 == 0 ? Color.clear : Color.primary.opacity(0.03))
        } else {
            labelledRow(label: row.0, text: row.1)
                .background(index % 2 == 0 ? Color.clear : Color.primary.opacity(0.03))
        }
    }

    private func calloutRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "link")
                .font(.caption.bold())
                .foregroundStyle(.orange)
                .padding(.top, 1)
            Text(.init(text))
                .font(.subheadline)
                .foregroundStyle(.orange)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private func labelledRow(label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline.bold())
                .frame(width: 110, alignment: .leading)
                .padding(.vertical, 7)
            Text(.init(text))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 7)
        }
        .padding(.horizontal, 12)
    }

    private func codeRow(_ text: String) -> some View {
        let command = text.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            // Spacer aligning code under the description column.
            Color.clear.frame(width: 110, height: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("", text: .constant(command))
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focusEffectDisabled()
                CopyButton(text: command, tint: .secondary)
            }
            .padding(.vertical, 5)
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Content

    private var topics: [HelpTopic] {
        var list: [HelpTopic] = [
            HelpTopic(
                icon: "plus.circle.fill", color: .blue,
                title: "Creating a Virtual Machine",
                rows: [
                    ("New…",          "Choose a name and location for a new VM bundle."),
                    ("Select ISO",    "Pick a Linux ISO matching your Mac's CPU — ARM64 (aarch64) on Apple Silicon, x86_64 on Intel."),
                    ("Configure",     "Set CPU cores and memory with the dropdowns before installing."),
                    ("Install",       "Click **Install VM…** and follow the guest OS installer. The VM window opens automatically."),
                ]
            ),
            HelpTopic(
                icon: "externaldrive.fill", color: .orange,
                title: "VM Bundles",
                rows: [
                    ("Select…",       "Switch to an existing `.bundle` directory on disk."),
                    ("Move…",         "Relocate the bundle to a new path — the app's bookmark updates automatically."),
                    ("Finder moves",  "Bundles moved or renamed in Finder are found automatically on next launch via file bookmarks."),
                    ("Delete",        "**Delete & Reinstall** permanently removes the bundle and all VM data."),
                    ("Multiple",      "Open **File ▸ New Window** (⌘N) to run several VMs at once — each window owns its own bundle and lifecycle."),
                ]
            ),
            HelpTopic(
                icon: "doc.on.doc.fill", color: .mint,
                title: "Cloning a VM",
                rows: [
                    ("Clone…",         "Click **Clone VM…** in the VM card to duplicate the current bundle, then choose a name and location for the copy."),
                    ("What's copied",  "The disk image (`Disk.img`), EFI variable store (`NVRAM`) and settings (`Config.json`) are duplicated. On APFS the disk is cloned copy-on-write, so even a large image copies almost instantly."),
                    ("Fresh identity", "SwiftVM writes a **new machine identifier** and generates **new MAC address(es)** for the clone automatically — the host and network never see two identical machines."),
                    ("!",              "Everything **inside** the disk is an exact copy. The guest's machine-id, SSH host keys and hostname stay duplicated until you regenerate them below. Running two un-regenerated clones at once can cause DHCP lease clashes and SSH host-key warnings."),
                    ("machine-id",     "Reset the guest's unique ID on systemd (Ubuntu/Debian), then reboot:"),
                    ("",               "`sudo rm -f /etc/machine-id /var/lib/dbus/machine-id && sudo systemd-machine-id-setup`"),
                    ("Void Linux",     "Void has no systemd — regenerate the id with dbus:"),
                    ("",               "`sudo sh -c 'dbus-uuidgen > /etc/machine-id'`"),
                    ("SSH host keys",  "Remove the copied keys so clients don't warn about a changed host identity:"),
                    ("",               "`sudo rm -f /etc/ssh/ssh_host_*`"),
                    ("Ubuntu",         "Regenerate: `sudo dpkg-reconfigure openssh-server`"),
                    ("Void Linux",     "Regenerate: `sudo ssh-keygen -A`"),
                    ("Hostname",       "Give the clone its own name on systemd:"),
                    ("",               "`sudo hostnamectl set-hostname <new-name>`"),
                    ("Void Linux",     "Set it directly in `/etc/hostname`:"),
                    ("",               "`echo <new-name> | sudo tee /etc/hostname`"),
                ]
            ),
            HelpTopic(
                icon: "slider.horizontal.3", color: .purple,
                title: "CPU & Memory",
                rows: [
                    ("CPU",           "Defaults to host core count minus one. Configurable per VM via the dropdown."),
                    ("Memory",        "Defaults to 4 GB. Configurable per VM via the dropdown."),
                    ("Saved",         "Settings are stored in `Config.json` inside the bundle and applied on next boot."),
                ]
            ),
            HelpTopic(
                icon: "gauge.with.dots.needle.67percent", color: .pink,
                title: "Performance",
                rows: [
                    ("Entropy",       "A virtio entropy device is always attached, giving the guest fast hardware randomness — speeds up first-boot crypto (e.g. SSH host key generation)."),
                    ("Disk Sync",     "Controls how the virtual disk flushes writes to the host:"),
                    ("Automatic",     "Full sync on every flush. Safest — survives host crashes and power loss without corruption."),
                    ("Fsync",         "Lighter-weight sync. Noticeably faster for builds and package installs; tiny risk of data loss if the host crashes mid-write."),
                    ("None",          "No disk sync at all. Fastest, but a host crash or force-quit can corrupt the VM's disk image — use only for disposable/test VMs."),
                    ("!",             "Disk Sync changes apply on next boot. If SwiftVM feels slower than other virtualization apps for disk-heavy work (compiling, package installs), try **Fsync**."),
                ]
            ),
            HelpTopic(
                icon: "terminal.fill", color: .green,
                title: "Headless / SSH Mode",
                rows: [
                    ("CLI runner",    "Run `./scripts/void-linux/run.sh` to start a VM without a display window."),
                    ("SSH",           "Connect with `ssh user@<ip>`. The VM's IP is shown by `ip addr show eth0` inside the guest."),
                    ("Stable IP",     "The MAC address is fixed per bundle so the VM gets the same DHCP lease each boot."),
                    ("Stop",          "Press **Ctrl+C** in the terminal to stop the VM gracefully."),
                ]
            ),
            HelpTopic(
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
            ),
        ]

        #if arch(arm64)
        list.append(
            HelpTopic(
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
        )
        #endif

        list.append(contentsOf: [
            HelpTopic(
                icon: "keyboard", color: .gray,
                title: "Shortcuts",
                rows: [
                    ("⌘ ↩",          "Start or install the current VM."),
                    ("⌘ R",          "Start or install the current VM (Run menu)."),
                    ("⌘ N",          "Open a new window to run another VM."),
                    ("⌘ ?",          "Open this Howto window."),
                    ("Ctrl+C",        "Stop the VM (CLI / headless mode)."),
                ]
            ),
            HelpTopic(
                icon: "puzzlepiece.extension.fill", color: .teal,
                title: "Guest OS Setup",
                rows: [
                    ("Void Linux",    "Use the manual chroot install — `void-installer` is not included in the live ISO."),
                    ("Kernel",        "`base-system` does **not** pull in the kernel. Run `xbps-install linux` explicitly inside the chroot."),
                    ("Post-install",  "Run `postinstall/void-linux/postinstall.sh` after first boot to set up XFCE, audio, and clipboard sharing."),
                    ("Ubuntu",        "Server ISOs: AMD64 at releases.ubuntu.com, ARM64 at cdimage.ubuntu.com/releases."),
                ]
            ),
        ])

        return list
    }
}
