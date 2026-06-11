import SwiftUI

/// V2.0 字阶:衬线读(New York via `.serif`),无衬线操作(SF Pro)。
/// 正文的 NSFont 版本在 MarkdownToAttributed(attributed string 管线)。
extension Font {
    /// 文章题:衬线 display(V1 的 42px 无衬线退役)。
    static let articleTitle = Font.system(size: 34, weight: .regular, design: .serif)
    static let h1 = Font.system(size: 28, weight: .medium, design: .serif)
    static let h2 = Font.system(size: 24, weight: .medium, design: .serif)
    static let h3 = Font.system(size: 19, weight: .medium, design: .serif)
    /// 正文(SwiftUI 侧引用;真正的正文渲染在 NSAttributedString 管线)。
    static let bodyArticle = Font.system(size: 18, weight: .regular, design: .serif)
    static let bodyChat = Font.system(size: 14, weight: .regular)
    static let metaText = Font.system(size: 12, weight: .regular)
    static let chipText = Font.system(size: 13, weight: .medium)
    static let pillBtn = Font.system(size: 14, weight: .medium)
    /// 大写微标签(保留的编辑风细节);调用处自行 `.textCase(.uppercase)` + `.tracking(0.9)`。
    static let eyebrow = Font.system(size: 11, weight: .medium)
}
