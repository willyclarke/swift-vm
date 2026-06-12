import SwiftUI

@main
struct SwiftVMApp: App {
    @StateObject private var manager = VirtualMachineManager()

    var body: some Scene {
        WindowGroup("Swift VM") {
            ContentView(manager: manager)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1280, height: 800)
        .commands {
            HelpCommands()
            AboutCommands()
            RunCommands(manager: manager)
        }

        Window("SwiftVM Help", id: "help") {
            HelpView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 680)

        Window("About SwiftVM", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}

struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About SwiftVM") {
                openWindow(id: "about")
            }
        }
    }
}

struct RunCommands: Commands {
    @ObservedObject var manager: VirtualMachineManager

    var body: some Commands {
        CommandMenu("Run") {
            Button(manager.bundleExists ? "Start Virtual Machine" : "Install VM…") {
                manager.start()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(manager.isRunning || manager.isStarting)
        }
    }
}

struct HelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("SwiftVM Help") {
                openWindow(id: "help")
            }
            .keyboardShortcut("?", modifiers: .command)
        }
    }
}
