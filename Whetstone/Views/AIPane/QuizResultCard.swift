import SwiftUI
import WhetstoneCore

/// 末尾出分结果卡：paperElevated 内容卡（与 Concept hero card 同构）。
/// 总分与三维方块用锈红表达（score 是锈红的合法用途）。
struct QuizResultCard: View {
    let conversation: Conversation

    /// 出分揭示:数字从 0 滚到总分(AI 时刻动效;Reduce Motion 时直接显示)。
    @State private var shownTotal: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var total: Int { conversation.score ?? 0 }

    var body: some View {
        let scores = (conversation.conceptScores ?? []).sorted { $0.orderIndex < $1.orderIndex }
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("COMPREHENSION")
                    .font(.eyebrow)
                    .tracking(0.9)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.rust)
            }

            Text("\(shownTotal)")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(Theme.rust)
                .contentTransition(.numericText(value: Double(shownTotal)))
                .onAppear {
                    if reduceMotion {
                        shownTotal = total
                    } else {
                        withAnimation(Motion.ai) { shownTotal = total }
                    }
                }

            Rectangle().fill(Theme.separator).frame(height: 1)

            if !scores.isEmpty {
                HStack {
                    Spacer()
                    Text("复 举 辨")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSecondary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(scores) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                Text(s.concept)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(glyphs(s.recall)) \(glyphs(s.apply)) \(glyphs(s.analyze))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.rust)
                            }
                            if !s.note.isEmpty {
                                Text(s.note)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                Rectangle().fill(Theme.separator).frame(height: 1)
            }

            Text(ScoreCalculator.overallDiagnosis(rows: scores.map { (recall: $0.recall, apply: $0.apply, analyze: $0.analyze) }))
                .font(.bodyChat)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .contentCard()
    }

    private func glyphs(_ v: Int) -> String {
        switch v {
        case 2: return "■■"
        case 1: return "■□"
        default: return "□□"
        }
    }
}
