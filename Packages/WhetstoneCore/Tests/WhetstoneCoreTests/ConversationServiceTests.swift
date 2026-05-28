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

    // MARK: - ask (quiz) — score parsing

    func testAskQuizCreatesQuizConversationAndParsesScore() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article); try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("不错的理解。\nSCORE: 73\n你还可以更深入。")
        let svc = ConversationService(ai: mock)

        let result = try await svc.ask(
            .quiz,
            in: nil,
            article: article,
            personaPromptLine: "用户是工程师。",
            context: ctx
        )

        XCTAssertEqual(result.conversation.mode, .quiz)
        XCTAssertEqual(result.conversation.score, 73)
        XCTAssertNotNil(result.conversation.endedAt)
        XCTAssertEqual(article.latestScore, 73)
    }

    func testAskQuizWithoutScoreLeavesScoreNil() async throws {
        let ctx = try makeInMemoryContext()
        let article = Article(url: "u", content: "body")
        ctx.insert(article); try ctx.save()

        let mock = MockAIClient()
        mock.sendResult = .success("第一个问题是什么?")
        let svc = ConversationService(ai: mock)

        let result = try await svc.ask(
            .quiz,
            in: nil,
            article: article,
            personaPromptLine: "用户是工程师。",
            context: ctx
        )
        XCTAssertNil(result.conversation.score)
        XCTAssertNil(article.latestScore)
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
