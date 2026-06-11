import SwiftUI
import WhetstoneCore

/// 中栏主场(未选文章时):标题 + 添加文章 + 统计 + 继续阅读 hero + 文章卡片网格。
struct LibraryHome: View {
    let articles: [Article]
    let onSelect: (Article) -> Void
    let onAddArticle: () -> Void
    let onDelete: (Article) -> Void
    var onSetStatus: ((ArticleStatus, Article) -> Void)? = nil

    @State private var filter: LibraryFilter = .all

    private var stats: LibraryStats { LibrarySelectors.stats(articles) }
    private var resume: Article? { LibrarySelectors.continueReading(articles) }
    private var shown: [Article] { LibrarySelectors.filtered(articles, query: "", filter: filter) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                statsLine.padding(.top, 14)

                if let resume {
                    sectionLabel("继续阅读").padding(.top, 30)
                    ContinueReadingHero(article: resume, onResume: { onSelect(resume) })
                        .padding(.top, 12)
                }

                if articles.isEmpty {
                    emptyState
                } else {
                    StatusLaneBar(filter: $filter, counts: LibrarySelectors.statusCounts(articles))
                        .padding(.top, 30)
                    if shown.isEmpty {
                        Text("这个泳道还没有文章")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 24)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 260), spacing: 18)],
                            alignment: .leading,
                            spacing: 18
                        ) {
                            ForEach(shown) { a in
                                LibraryCard(
                                    article: a,
                                    onTap: { onSelect(a) },
                                    onDelete: { onDelete(a) },
                                    onSetStatus: onSetStatus.map { f in { f($0, a) } }
                                )
                            }
                        }
                        .padding(.top, 14)
                    }
                }
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("文章库")
                .font(.articleTitle)
                .foregroundStyle(Theme.ink)
            Spacer()
            Button(action: onAddArticle) {
                Text("+ 添加文章")
            }
            .buttonStyle(EditorialButtonStyle(size: .large, variant: .primary))
            .fixedSize()
        }
        .padding(.top, 28)
    }

    private var statsLine: some View {
        HStack(spacing: 18) {
            stat("\(stats.count)", "篇文章")
            stat("\(stats.masteredCount)", "已掌握")
            if let avg = stats.averageScore {
                stat("\(avg)", "平均分")
            }
        }
    }

    /// 统计项:数字 + eyebrow 微标签
    private func stat(_ n: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(n).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
            Text(label)
                .font(.eyebrow)
                .textCase(.uppercase)
                .tracking(0.9)
                .foregroundStyle(.secondary)
        }
    }

    /// 区块标题:eyebrow 微标签
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.eyebrow)
            .textCase(.uppercase)
            .tracking(0.9)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("还没有文章")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
            Text("点右上角「+ 添加文章」,粘贴一个链接试试。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
