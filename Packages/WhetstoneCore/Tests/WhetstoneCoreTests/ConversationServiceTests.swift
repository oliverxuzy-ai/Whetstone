import XCTest
import SwiftData
@testable import WhetstoneCore

@MainActor
final class ConversationServiceTests: XCTestCase {

    // MARK: - extractConcepts

    func testExtractConceptsInsertsAndPersists() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "Some article body about quantum stuff.")
        ctx.insert(article); try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("""
        [
          {"name": "Qubits", "explanation": "量子比特"},
          {"name": "Superposition", "explanation": "叠加态"}
        ]
        """)
        let svc = ConversationService(ai: mock)

        let concepts = try await svc.extractConcepts(for: article, context: ctx)

        XCTAssertEqual(concepts.count, 2)
        XCTAssertEqual(concepts.map(\.name), ["Qubits", "Superposition"])
        XCTAssertEqual(concepts.map(\.orderIndex), [0, 1])
        // Inserted onto the article + persisted
        let stored = (article.concepts ?? []).sorted { $0.orderIndex < $1.orderIndex }
        XCTAssertEqual(stored.map(\.name), ["Qubits", "Superposition"])
        XCTAssertEqual(mock.sendCallCount, 1)
    }

    func testExtractConceptsAIFailureSurfaces() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article); try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .failure(AIClientError.invalidResponse)
        let svc = ConversationService(ai: mock)

        do {
            _ = try await svc.extractConcepts(for: article, context: ctx)
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(error as? AIClientError, .invalidResponse)
        }
        XCTAssertEqual(article.concepts?.count ?? 0, 0)
    }

    // MARK: - ask (free question)

    func testAskFreeQuestionAppendsAssistantMessage() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article); try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("这是答案。")
        let svc = ConversationService(ai: mock)

        let result = try await svc.ask(
            .free(question: "什么是叠加态?"),
            in: nil,
            article: article,
            personaPromptLine: "用户是工程师。",
            context: ctx
        )

        // A conversation was created in companion mode
        XCTAssertEqual(result.conversation.mode, .companion)
        // The user message + assistant message are both on the conversation
        let msgs = (result.conversation.messages ?? []).sorted { $0.timestamp < $1.timestamp }
        XCTAssertEqual(msgs.count, 2)
        XCTAssertEqual(msgs.first?.role, .user)
        XCTAssertEqual(msgs.last?.role, .ai)
        XCTAssertEqual(result.aiMessage.role, .ai)
        XCTAssertEqual(result.aiMessage.content, "这是答案。")
        // User message uses the short display version, not the full injected prompt
        XCTAssertEqual(result.userMessage.content, "什么是叠加态?")
    }

    func testAskReusesExistingConversation() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        let conv = Conversation(mode: .companion, article: article)
        ctx.insert(article); ctx.insert(conv); try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("answer")
        let svc = ConversationService(ai: mock)

        let result = try await svc.ask(
            .free(question: "q"),
            in: conv,
            article: article,
            personaPromptLine: "用户是工程师。",
            context: ctx
        )
        XCTAssertTrue(result.conversation === conv)
    }

    // MARK: - ask (quiz) — 控制标记 + 进度

    func testAskQuizStartsQuizConversationAndStripsMark() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article)
        ctx.insert(Concept(name: "A", explanation: "a", orderIndex: 0, article: article))
        ctx.insert(Concept(name: "B", explanation: "b", orderIndex: 1, article: article))
        try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("先问第一个概念：你怎么理解 A？")
        let svc = ConversationService(ai: mock)

        let result = try await svc.ask(.quiz, in: nil, article: article, personaPromptLine: "", context: ctx)

        XCTAssertEqual(result.conversation.mode, .quiz)
        XCTAssertFalse(result.quizDone)
        XCTAssertTrue(mock.lastSystemPrompt.contains("A — a"))
        XCTAssertEqual(result.aiMessage.content, "先问第一个概念：你怎么理解 A？")
    }

    func testAskQuizReplyStripsNextMarkAndReportsProgress() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article)
        ctx.insert(Concept(name: "A", explanation: "a", orderIndex: 0, article: article))
        try ctx.save()
        let conv = Conversation(mode: .quiz, article: article)
        ctx.insert(conv)
        try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("不错。\n<<NEXT concept=2>>")
        let svc = ConversationService(ai: mock)

        let result = try await svc.ask(.quizReply(answer: "我的回答"), in: conv, article: article, personaPromptLine: "", context: ctx)

        XCTAssertEqual(result.aiMessage.content, "不错。")
        XCTAssertEqual(result.quizCurrentConcept, 2)
        XCTAssertEqual(result.userMessage.content, "我的回答")
        XCTAssertFalse(result.quizDone)
    }

    func testAskQuizReplyDetectsDone() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article)
        ctx.insert(Concept(name: "A", explanation: "a", orderIndex: 0, article: article))
        try ctx.save()
        let conv = Conversation(mode: .quiz, article: article)
        ctx.insert(conv)
        try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("都问完了。\n<<DONE>>")
        let svc = ConversationService(ai: mock)

        let result = try await svc.ask(.quizReply(answer: "答"), in: conv, article: article, personaPromptLine: "", context: ctx)
        XCTAssertTrue(result.quizDone)
        XCTAssertEqual(result.aiMessage.content, "都问完了。")
    }

    func testAskQuizReplyForcesDoneAtTurnCap() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article)
        ctx.insert(Concept(name: "A", explanation: "a", orderIndex: 0, article: article))
        try ctx.save()
        let conv = Conversation(mode: .quiz, article: article)
        ctx.insert(conv)
        // 1 个概念 → cap = 1 + 2 = 3。预置 2 个 .ai 轮，本次 reply 产生第 3 个 → 达 cap 强制收尾。
        ctx.insert(Message(role: .ai, content: "q1", conversation: conv))
        ctx.insert(Message(role: .ai, content: "q2", conversation: conv))
        try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("再追问一句，没有结束标记")
        let svc = ConversationService(ai: mock)

        let result = try await svc.ask(.quizReply(answer: "答"), in: conv, article: article, personaPromptLine: "", context: ctx)
        XCTAssertTrue(result.quizDone)
    }

    // MARK: - gradeQuiz

    func testGradeQuizAggregatesAndPersists() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article)
        ctx.insert(Concept(name: "A", explanation: "a", orderIndex: 0, article: article))
        ctx.insert(Concept(name: "B", explanation: "b", orderIndex: 1, article: article))
        try ctx.save()
        let conv = Conversation(mode: .quiz, article: article)
        ctx.insert(conv)
        ctx.insert(Message(role: .ai, content: "问 A", conversation: conv))
        ctx.insert(Message(role: .user, content: "答 A", conversation: conv))
        try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success(#"""
        [
          {"concept":"A","recall":2,"apply":2,"analyze":2,"note":"透彻"},
          {"concept":"B","recall":2,"apply":1,"analyze":0,"note":"举例勉强"}
        ]
        """#)
        let svc = ConversationService(ai: mock)

        let total = try await svc.gradeQuiz(conv, article: article, context: ctx)

        // A(2,2,2)=100；B(2,1,0)=(2×1+1×2+0×3)/12×100=33 -> mean(100,33)=66.5 -> 67
        XCTAssertEqual(total, 67)
        XCTAssertEqual(conv.score, 67)
        XCTAssertEqual(article.latestScore, 67)
        XCTAssertNotNil(conv.endedAt)
        XCTAssertEqual(conv.conceptScores?.count, 2)
        XCTAssertEqual(mock.temperatures.last, 0)   // 评分员 temp 0
    }

    func testGradeQuizThrowsOnBadJSONAndDoesNotPersistScore() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article)
        ctx.insert(Concept(name: "A", explanation: "a", orderIndex: 0, article: article))
        try ctx.save()
        let conv = Conversation(mode: .quiz, article: article)
        ctx.insert(conv)
        try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("这不是 JSON")
        let svc = ConversationService(ai: mock)

        do {
            _ = try await svc.gradeQuiz(conv, article: article, context: ctx)
            XCTFail("should throw")
        } catch {
            // ok
        }
        XCTAssertNil(conv.score)
        XCTAssertNil(article.latestScore)
        XCTAssertEqual(conv.conceptScores?.count ?? 0, 0)
    }

    // MARK: - ask failure surfaces

    func testAskAIFailureSurfaces() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article); try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .failure(AIClientError.invalidResponse)
        let svc = ConversationService(ai: mock)

        do {
            _ = try await svc.ask(
                .free(question: "q"),
                in: nil,
                article: article,
                personaPromptLine: "用户是工程师。",
                context: ctx
            )
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(error as? AIClientError, .invalidResponse)
        }
    }
}
