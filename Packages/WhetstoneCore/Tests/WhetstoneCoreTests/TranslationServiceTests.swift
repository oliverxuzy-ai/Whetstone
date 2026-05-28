import XCTest
import SwiftData
@testable import WhetstoneCore

@MainActor
final class TranslationServiceTests: XCTestCase {
    func testUsesCacheWhenPresent() async throws {
        let ctx = try makeInMemoryContext()
        let a = Article(url: "u", content: "Para one.\n\nPara two.")
        a.setTranslatedParagraphs(["甲", "乙"])
        ctx.insert(a); try ctx.save()
        let mock = MockAIClient()
        mock.translateResult = .failure(AIClientError.invalidResponse) // would throw if called
        let svc = TranslationService(ai: mock)
        let result = try await svc.ensureTranslation(for: a, context: ctx)
        XCTAssertEqual(result, ["甲", "乙"])
    }

    func testCallsAIAndPersistsWhenNoCache() async throws {
        let ctx = try makeInMemoryContext()
        let a = Article(url: "u", content: "Para one.\n\nPara two.")
        ctx.insert(a); try ctx.save()
        let mock = MockAIClient()
        mock.translateResult = .success(["甲", "乙"])
        let svc = TranslationService(ai: mock)
        let result = try await svc.ensureTranslation(for: a, context: ctx)
        XCTAssertEqual(result, ["甲", "乙"])
        XCTAssertEqual(a.translatedParagraphs, ["甲", "乙"])  // persisted onto the model
    }

    func testThrowsWhenContentEmpty() async throws {
        let ctx = try makeInMemoryContext()
        let a = Article(url: "u", content: "")
        ctx.insert(a); try ctx.save()
        let svc = TranslationService(ai: MockAIClient())
        do { _ = try await svc.ensureTranslation(for: a, context: ctx); XCTFail("should throw") }
        catch { /* expected: empty content */ }
    }
}
