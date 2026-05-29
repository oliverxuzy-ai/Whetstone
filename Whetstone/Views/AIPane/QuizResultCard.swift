import SwiftUI
import WhetstoneCore

/// 末尾出分结果卡：复刻 Concept hero card 构造（cream + 1px 黑边 + 直角）。
/// 三维用黑/空心方块表达，不使用强调色（brutalist 约束）。
struct QuizResultCard: View {
    let conversation: Conversation

    var body: some View {
        let scores = (conversation.conceptScores ?? []).sorted { $0.orderIndex < $1.orderIndex }
        let total = conversation.score ?? 0
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("COMPREHENSION")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(Theme.textPrimary.opacity(0.5))
                Spacer()
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.rust)
            }

            Text("\(total)")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(Theme.rust)

            Rectangle().fill(Theme.borderHeavy).frame(height: 1)

            if !scores.isEmpty {
                HStack {
                    Spacer()
                    Text("复 举 辨")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textPrimary.opacity(0.5))
                }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(scores) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                Text(s.concept)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(glyphs(s.recall)) \(glyphs(s.apply)) \(glyphs(s.analyze))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            if !s.note.isEmpty {
                                Text(s.note)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textPrimary.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                Rectangle().fill(Theme.borderHeavy).frame(height: 1)
            }

            Text(ScoreCalculator.overallDiagnosis(rows: scores.map { (recall: $0.recall, apply: $0.apply, analyze: $0.analyze) }))
                .font(.bodyChat)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .hardShadow(fill: Theme.bgCream)
    }

    private func glyphs(_ v: Int) -> String {
        switch v {
        case 2: return "■■"
        case 1: return "■□"
        default: return "□□"
        }
    }
}
