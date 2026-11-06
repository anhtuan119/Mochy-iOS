import SwiftUI

@main
struct MochyApp: App {
    @StateObject private var library = MusicLibrary()
    @StateObject private var player = MusicPlayer()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(library).environmentObject(player)
                .preferredColorScheme(.dark).tint(.mint)
        }
    }
}
