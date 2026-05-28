import XCTest
@testable import WhetstoneCore

final class AIClientTests: XCTestCase {
    func testMockSendReturnsConfiguredResult() async throws {
        let mock = MockAIClient()
        mock.sendResult = .success("hi")
        let out = try await mock.send(systemPrompt: "s", messages: [AIMessage(role: "user", content: "q")], maxTokens: 10, temperature: nil, cacheArticleContent: nil)
        XCTAssertEqual(out, "hi")
        XCTAssertEqual(mock.sendCallCount, 1)
    }
    func testMockTranslateThrowsConfiguredError() async {
        let mock = MockAIClient()
        mock.translateResult = .failure(AIClientError.invalidResponse)
        do { _ = try await mock.translate(paragraphs: ["a"]); XCTFail("should throw") }
        catch { XCTAssertEqual(error as? AIClientError, .invalidResponse) }
    }
}
