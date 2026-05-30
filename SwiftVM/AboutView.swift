import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .padding(.top, 28)

            Text("SwiftVM")
                .font(.title.bold())
                .padding(.top, 12)

            Text("macOS virtual machines using Apple's Virtualization framework.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 24)

            Divider()
                .padding(.top, 20)

            HStack(spacing: 32) {
                infoItem("Version", version)
                infoItem("Commit", BuildInfo.gitHash)
            }
            .padding(.vertical, 14)
        }
        .frame(width: 300)
    }

    private func infoItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
