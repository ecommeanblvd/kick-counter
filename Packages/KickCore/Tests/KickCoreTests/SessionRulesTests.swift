import Testing
@testable import KickCore

@Test func rulesMatchCardiffMethod() {
    #expect(SessionRules.targetCount == 10)
    #expect(SessionRules.overdueThreshold == 2 * 60 * 60)
    #expect(SessionRules.debounceInterval == 0.5)
    #expect(SessionRules.abandonAfter == 12 * 60 * 60)
    #expect(SessionRules.liveActivityMaxAge == 8 * 60 * 60)
}
