import Foundation
import SwiftData

@Model
public final class Highlight {
    public var id: UUID = UUID()
    /// Identifies the parent article. Uses article.url for stability across
    /// SwiftData persistentModelID changes (e.g., after store migration).
    public var articleID: String = ""
    public var charStart: Int = 0
    public var charEnd: Int = 0
    /// Snapshot of the highlighted text — used as fallback to re-anchor the
    /// highlight if article.content is rewritten (e.g., user toggles AI enhance
    /// and the same article is re-fetched).
    public var selectedText: String = ""
    /// RGB hex of the highlight background. Alpha is applied at render time
    /// (currently 0.45 per design spec).
    public var colorHex: UInt32 = 0xD8C66A
    public var createdAt: Date = Date()

    public init(articleID: String, charStart: Int, charEnd: Int, selectedText: String, colorHex: UInt32 = 0xD8C66A) {
        self.articleID = articleID
        self.charStart = charStart
        self.charEnd = charEnd
        self.selectedText = selectedText
        self.colorHex = colorHex
        self.createdAt = Date()
    }
}
