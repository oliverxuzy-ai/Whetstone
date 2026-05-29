import SwiftUI
import WhetstoneCore

/// 中栏主场(未选文章时):标题 + 添加文章 + 统计 + 继续阅读 hero + 文章卡片网格。
struct LibraryHome: View {
    let articles: [Article]
    let onSelect: (Article) -> Void
    let onAddArticle: () -> Void
    let onDelete: (Article) -> Void

    private var stats: LibraryStats { LibrarySelectors.stats(articles) }
    private var resume: Article? { LibrarySelectors.continueReading(articles) }

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
                    sectionLabel("最近").padding(.top, 30)
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 260), spacing: 16)],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(articles) { a in
                            LibraryCard(article: a, onTap: { onSelect(a) }, onDelete: { onDelete(a) })
                        }
                    }
                    .padding(.top, 12)
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
                .font(.system(size: 40, weight: .regular))
                .tracking(-0.02)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Button(action: onAddArticle) {
                Text("+ 添加文章")
            }
            .buttonStyle(EditorialButtonStyle(size: .large, variant: .primary))
            .fixedSize()
        }
        .padding(.top, 28 + Theme.titlebarInset)
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

    private func stat(_ n: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(n).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.textPrimary)
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.14 * 11)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("还没有文章")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text("点右上角「+ 添加文章」,粘贴一个链接试试。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
