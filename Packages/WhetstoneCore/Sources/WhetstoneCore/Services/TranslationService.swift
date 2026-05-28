import Foundation
import SwiftData
import os

public enum TranslationServiceError: LocalizedError {
    case emptyContent
    public var errorDescription: String? {
        switch self { case .emptyContent: return "文章内容为空,没东西可翻译。" }
    }
}

/// Owns "ensure this article has a translation (use cache or call AI), persist it".
/// Touches SwiftData's ModelContext, which is main-actor bound, so the whole type
/// is `@MainActor` (an `actor` would only hop straight back to the main actor for
/// the single method below — no concurrency benefit, just friction).
@MainActor
public final class TranslationService {
    private let ai: AIClient
    public init(ai: AIClient) { self.ai = ai }

    /// Returns the article's Chinese paragraphs: cached if present, otherwise
    /// calls the AI, persists onto the model, and returns them. Throws on empty
    /// content or if the AI call / save fails (no silent failure — Bug #1).
    public func ensureTranslation(for article: Article, context: ModelContext) async throws -> [String] {
        if let cached = article.translatedParagraphs { return cached }
        let paragraphs = ParagraphSplitter.split(article.content)
        guard !paragraphs.isEmpty else { throw TranslationServiceError.emptyContent }
        let zh = try await ai.translate(paragraphs: paragraphs)
        article.setTranslatedParagraphs(zh)
        do {
            try context.save()   // Bug #1: surface save failures, do not swallow
        } catch {
            Log.persistence.error("TranslationService save failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        return zh
    }
}
