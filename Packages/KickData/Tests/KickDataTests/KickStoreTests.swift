import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

@MainActor
struct KickStoreTests {
    let t0 = date("2026-09-01T20:00:00Z")
    let container: ModelContainer
    let store: KickStore

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        store = KickStore(context: container.mainContext)
    }

    @Test func noActiveSessionInitially() throws {
        #expect(try store.activeSession() == nil)
    }

    @Test func firstKickStartsSessionAndCountsOne() throws {
        let result = try store.addKick(at: t0)
        #expect(result.didStartSession)
        #expect(result.outcome == .added(count: 1))
        #expect(result.record.state.startedAt == t0)
        #expect(try store.activeSession()?.id == result.record.id)
    }

    @Test func subsequentKicksReuseActiveSession() throws {
        let first = try store.addKick(at: t0)
        let second = try store.addKick(at: t0.addingTimeInterval(30))
        #expect(second.didStartSession == false)
        #expect(second.record.id == first.record.id)
        #expect(second.outcome == .added(count: 2))
    }

    @Test func tenKicksCompleteAndPersistState() throws {
        var last: KickResult?
        for i in 0..<10 { last = try store.addKick(at: t0.addingTimeInterval(Double(i) * 60)) }
        #expect(last?.outcome == .completed(duration: 540))
        #expect(try store.activeSession() == nil)

        let saved = try container.mainContext.fetch(FetchDescriptor<KickSession>())
        #expect(saved.count == 1)
        #expect(saved[0].status == .completed)
        #expect(saved[0].state.count == 10)
        #expect(saved[0].endedAt == t0.addingTimeInterval(540))
    }

    @Test func kickAfterCompletionStartsNewSession() throws {
        for i in 0..<10 { _ = try store.addKick(at: t0.addingTimeInterval(Double(i) * 60)) }
        let next = try store.addKick(at: t0.addingTimeInterval(3600))
        #expect(next.didStartSession)
        #expect(next.outcome == .added(count: 1))
    }

    @Test func undoRemovesPersistedKick() throws {
        _ = try store.addKick(at: t0)
        _ = try store.addKick(at: t0.addingTimeInterval(10))
        let record = try store.undoLastKick()
        #expect(record?.state.kicks == [t0])
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Kick>()) == 1)
    }

    @Test func undoWithoutActiveSessionReturnsNil() throws {
        #expect(try store.undoLastKick() == nil)
    }

    @Test func cancelMarksSessionCancelled() throws {
        _ = try store.addKick(at: t0)
        let cancelled = try store.cancelActive(at: t0.addingTimeInterval(120))
        #expect(cancelled?.state.status == .cancelled)
        #expect(cancelled?.state.endedAt == t0.addingTimeInterval(120))
        #expect(try store.activeSession() == nil)
    }

    @Test func duplicateActiveSessionsAreResolvedToNewest() throws {
        // Simulates two devices each starting a session, merged by iCloud sync.
        let older = KickSession(startedAt: t0)
        let newer = KickSession(startedAt: t0.addingTimeInterval(600))
        container.mainContext.insert(older)
        container.mainContext.insert(newer)
        try container.mainContext.save()

        #expect(try store.activeSession()?.id == newer.id)
        #expect(older.status == .cancelled)
    }
}
