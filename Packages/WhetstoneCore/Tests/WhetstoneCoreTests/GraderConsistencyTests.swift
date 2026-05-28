import XCTest
@testable import WhetstoneCore

/// 需真实 OpenAI key：`WHETSTONE_TEST_API_KEY=sk-... swift test --filter GraderConsistencyTests`
/// 无 key 时自动跳过，所以 CI 默认不跑。
final class GraderConsistencyTests: XCTestCase {

    private static let conceptList = """
    1. Qubits — 量子比特，量子信息的基本单位
    2. Superposition — 叠加态，量子比特可同时处于多个状态
    """

    private static let transcript = """
    导师: 你怎么用自己的话解释 qubit？
    用户: qubit 就像经典比特，但它可以同时是 0 和 1，因为叠加。
    导师: 能举个 superposition 在测量时会发生什么的例子吗？
    用户: 测量会让它塌缩到 0 或 1 其中一个，测量前是概率分布。
    导师: 那 qubit 和经典比特的本质区别是什么？
    用户: 经典比特只能存一个值，qubit 能用叠加和纠缠存更多信息。
    """

    func testGraderScoreIsStableAcrossRuns() async throws {
        guard let key = ProcessInfo.processInfo.environment["WHETSTONE_TEST_API_KEY"], !key.isEmpty else {
            throw XCTSkip("需要 WHETSTONE_TEST_API_KEY 才能跑一致性集成测试")
        }
        let client = OpenAIClient(apiKeyProvider: { key })
        let names = ["Qubits", "Superposition"]

        var totals: [Int] = []
        for _ in 0..<5 {
            let reply = try await client.send(
                systemPrompt: Prompts.graderSystem,
                messages: [AIMessage(role: "user", content: Prompts.graderUser(conceptList: Self.conceptList, transcript: Self.transcript))],
                maxTokens: 1500,
                temperature: 0,
                cacheArticleContent: nil
            )
            let rows = try ResponseParser.conceptScores(reply, expectedConcepts: names)
            let percents = rows.map { ScoreCalculator.conceptPercent(recall: $0.recall, apply: $0.apply, analyze: $0.analyze) }
            if let total = ScoreCalculator.totalScore(percents) { totals.append(total) }
        }

        XCTAssertEqual(totals.count, 5)
        let range = (totals.max() ?? 0) - (totals.min() ?? 0)
        XCTAssertLessThanOrEqual(range, 8, "5 次评分总分极差 \(range) 超过容忍阈值 8；totals=\(totals)")
    }
}
