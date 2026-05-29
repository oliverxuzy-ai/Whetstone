import Foundation
import WhetstoneCore

/// 文章卡片用的显示派生(host / 相对时间)。纯展示,放 app target 而非 Core。
extension Article {
    /// 去掉 scheme 与 www. 的来源域名,用于卡片副标题。
    var sourceHost: String {
        guard let host = URL(string: url)?.host else { return url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// 相对添加时间,例如 "2天前"。
    var relativeAdded: String {
        Article.relFormatter.localizedString(for: fetchedAt, relativeTo: Date())
    }

    private static let relFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()
}
