import XCTest
import SwiftData
@testable import WhetstoneCore

@MainActor
final class ConceptScoreTests: XCTestCase {
    func testConceptScorePersistsAndLinksToConversation() throws {
        let ctx = try makeInMemoryContext()
        let conv = Conversation(mode: .quiz)
        ctx.insert(conv)
        let cs = ConceptScore(concept: "Qubits", recall: 2, apply: 1, analyze: 0, note: "举例勉强", conversation: conv)
        ctx.insert(cs)
        try ctx.save()

        XCTAssertEqual(conv.conceptScores?.count, 1)
        XCTAssertEqual(conv.conceptScores?.first?.concept, "Qubits")
        XCTAssertEqual(conv.conceptScores?.first?.recall, 2)
    }

    func testDeletingConversationCascadesConceptScores() throws {
        let ctx = try makeInMemoryContext()
        let conv = Conversation(mode: .quiz)
        ctx.insert(conv)
        ctx.insert(ConceptScore(concept: "A", recall: 1, apply: 1, analyze: 1, note: "n", conversation: conv))
        try ctx.save()

        ctx.delete(conv)
        try ctx.save()

        let remaining = try ctx.fetch(FetchDescriptor<ConceptScore>())
        XCTAssertEqual(remaining.count, 0)
    }

    func testConceptScorePreservesOrderIndex() throws {
        let ctx = try makeInMemoryContext()
        let conv = Conversation(mode: .quiz)
        ctx.insert(conv)
        ctx.insert(ConceptScore(concept: "B", recall: 1, apply: 1, analyze: 1, note: "n", orderIndex: 1, conversation: conv))
        ctx.insert(ConceptScore(concept: "A", recall: 2, apply: 2, analyze: 2, note: "n", orderIndex: 0, conversation: conv))
        try ctx.save()

        let ordered = (conv.conceptScores ?? []).sorted { $0.orderIndex < $1.orderIndex }
        XCTAssertEqual(ordered.map(\.concept), ["A", "B"])
    }
}
