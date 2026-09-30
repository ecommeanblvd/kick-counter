import AppIntents
import Foundation

/// Set by the app at launch. LiveActivityIntent.perform runs in the app's
/// process, so the handler is always present when the intent fires.
@MainActor
enum KickIntentBridge {
    static var recordKick: (@MainActor () async -> Void)?
}

struct AddKickIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "intent.addKick.title"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await KickIntentBridge.recordKick?()
        return .result()
    }
}
