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
    }
}
