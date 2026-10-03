import KickCore
import SwiftUI

private struct ContentLibraryKey: EnvironmentKey {
    static let defaultValue: WeeklyContentLibrary? = nil
}

extension EnvironmentValues {
    /// The bundled week-by-week content; nil if it failed to load (cards are hidden).
    var contentLibrary: WeeklyContentLibrary? {
        get { self[ContentLibraryKey.self] }
        set { self[ContentLibraryKey.self] = newValue }
    }
}

enum BuildFlags {
    /// Debug and TestFlight builds (`CONTENT_PREVIEW`, set by testflight.yml through
    /// release.sh) show all content with a "pending review" label; App Store builds
    /// show only content an obstetrician has marked `reviewed`.
    static var contentVisibility: ContentVisibility {
        #if DEBUG || CONTENT_PREVIEW
        return .all
        #else
        return .reviewedOnly
        #endif
    }
}
