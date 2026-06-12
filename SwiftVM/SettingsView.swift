import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("backgroundImagePath") private var backgroundImagePath: String = ""
    @AppStorage("backgroundBlurRadius") private var backgroundBlurRadius: Double = 3

    var body: some View {
        Form {
            Section("Background") {
                HStack(spacing: 12) {
                    backgroundPreview
                        .frame(width: 60, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(backgroundImagePath.isEmpty ? "Default gradient" : URL(fileURLWithPath: backgroundImagePath).lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("Shown behind the main window")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !backgroundImagePath.isEmpty {
                        Button("Reset") {
                            backgroundImagePath = ""
                        }
                    }
                    Button("Choose Image…") {
                        chooseImage()
                    }
                }

                LabeledContent("Blur") {
                    HStack {
                        Slider(value: $backgroundBlurRadius, in: 0...20, step: 1)
                        Text("\(Int(backgroundBlurRadius))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
                .disabled(backgroundImagePath.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    @ViewBuilder
    private var backgroundPreview: some View {
        if !backgroundImagePath.isEmpty, let nsImage = NSImage(contentsOfFile: backgroundImagePath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.35), Color(.windowBackgroundColor)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.title = "Choose Background Image"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url {
            backgroundImagePath = url.path
        }
    }
}
