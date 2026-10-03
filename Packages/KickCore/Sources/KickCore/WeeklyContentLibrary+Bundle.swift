import Foundation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "content")

public enum ContentLoadError: Error, Equatable {
    case resourceMissing
}

extension WeeklyContentLibrary {
    public static let resourceName = "pregnancy-content"

    /// The content bundled in KickCore's resources. Throws if it is missing or malformed.
    public static func bundled() throws -> WeeklyContentLibrary {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json") else {
            throw ContentLoadError.resourceMissing
        }
        return try WeeklyContentLibrary(data: Data(contentsOf: url))
    }

    /// Like `bundled()`, but logs and returns nil instead of throwing, so the app
    /// hides the content cards while the week calculation keeps working.
    public static func loadBundled() -> WeeklyContentLibrary? {
        do {
            return try bundled()
        } catch {
            logger.error("Loading pregnancy content failed: \(error.localizedDescription)")
            return nil
        }
    }
}
