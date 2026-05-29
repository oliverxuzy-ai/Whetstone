import Foundation
@testable import WhetstoneCore

final class MockAIClient: AIClient, @unchecked Sendable {
    /// 单一结果（队列空时的回退）——兼容老测试。
    var sendResult: Result<String, Error> = .success("")
    /// 顺序响应队列：多次 send 依次取（如导师轮 + 评分员）。非空时优先于 sendResult。
    var sendResults: [Result<String, Error>] = []
    var translateResult: Result<[String], Error> = .success([])

    private(set) var sendCallCount = 0
    private(set) var temperatures: [Double?] = []
    private(set) var lastSystemPrompt: String = ""
    private(set) var lastMessages: [AIMessage] = []

    func send(systemPrompt: String, messages: [AIMessage], maxTokens: Int, temperature: Double?, cacheArticleContent: String?) async throws -> String {
        sendCallCount += 1
        temperatures.append(temperature)
        lastSystemPrompt = systemPrompt
        lastMessages = messages
        if !sendResults.isEmpty {
            return try sendResults.removeFirst().get()
        }
        return try sendResult.get()
    }

    func translate(paragraphs: [String]) async throws -> [String] { try translateResult.get() }
    func enhanceLayout(rawText: String) async throws -> String { try sendResult.get() }
}
