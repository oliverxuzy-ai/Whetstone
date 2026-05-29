import SwiftUI
import WhetstoneCore

/// "Concepts Extracted" hero card + concept rows + suggestion chip strip.
/// Pure view: it renders `article.concepts` and emits ask intents via `onAsk`.
struct ConceptCardView: View {
    let article: Article
    let conceptsLoaded: Bool
    let onAsk: (AIPane.AskKind) -> Void

    var body: some View {
        let concepts = (article.concepts ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })
        if !concepts.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Concepts Extracted")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.rust)
                    Spacer()
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.rust)
                }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(concepts) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Text(c.explanation)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textPrimary.opacity(0.9))
                        }
                    }
                }
                // Chip strip: N "explain" chips（quiz 入口已移到 header QuizEntryButton）。AI pane is only ~360pt wide
                // after padding, so concept-specific labels truncate the concept name to
                // avoid overflow and the row wraps via LazyVGrid (NOT HStack — long
                // Chinese+English labels won't fit on one row).
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                          alignment: .leading, spacing: 8) {
                    ForEach(concepts.prefix(3)) { c in
                        chip("类比「\(truncated(c.name, max: 12))」") {
                            onAsk(.explain(concept: c.name))
                        }
                    }
                }
            }
            .padding(20)
            .hardShadow(fill: Theme.bgCream)
        } else if !conceptsLoaded {
            HStack {
                ProgressView().controlSize(.small)
                Text("提取核心概念中...")
                    .font(.bodyChat)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func chip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .lineLimit(1)
        }
        .buttonStyle(EditorialButtonStyle(size: .small, variant: .secondary))
    }

    private func truncated(_ s: String, max: Int) -> String {
        if s.count <= max { return s }
        return String(s.prefix(max)) + "…"
    }
}
