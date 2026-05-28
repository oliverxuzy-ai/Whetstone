import Foundation
@testable import WhetstoneCore

final class MockAIClient: AIClient, @unchecked Sendable {
    var sendResult: Result<String, Error> = .success("")
    var translateResult: Result<[String], Error> = .success([])
    private(set) var sendCallCount = 0

    func send(systemPrompt: String, messages: [AIMessage], maxTokens: Int, cacheArticleContent: String?) async throws -> String {
        sendCallCount += 1
        return try sendResult.get()
    }
    func translate(paragraphs: [String]) async throws -> [String] { try translateResult.get() }
    func enhanceLayout(rawText: String) async throws -> String { try sendResult.get() }
}
