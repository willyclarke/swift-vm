import SwiftUI

@main
struct SwiftVMApp: App {
    var body: some Scene {
        WindowGroup("Swift VM") {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1280, height: 800)
        .commands {
            HelpCommands()
            AboutCommands()
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
