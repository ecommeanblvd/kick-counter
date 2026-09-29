import SwiftUI
import KickCore

@main
struct KickCounterApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Kick Counter — \(SessionRules.targetCount)")
        }
    }
}
