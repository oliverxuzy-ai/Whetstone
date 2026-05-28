import Foundation

/// 把每概念三维 0/1/2 评分聚合成分数。纯函数、无依赖、可确定性测试。
/// 这是打分一致性的核心：模型只产出 0/1/2 小项，总分由这里算，模型从不直接给总分。
public enum ScoreCalculator {

    /// 单概念得分 (0...100)。权重：复述 1 / 举例 2 / 辨析 3，满分 12。
    /// 任一维越界（非 0/1/2）按 0 计 —— 保守，证据不足不给分。
    public static func conceptPercent(recall: Int, apply: Int, analyze: Int) -> Int {
        let r = valid(recall), a = valid(apply), an = valid(analyze)
        let raw = r * 1 + a * 2 + an * 3   // max = 2+4+6 = 12
        return Int((Double(raw) / 12.0 * 100.0).rounded())
    }

    /// 文章总分 = 各概念分的算术平均（等权），四舍五入。无概念时为 nil。
    public static func totalScore(_ conceptPercents: [Int]) -> Int? {
        guard !conceptPercents.isEmpty else { return nil }
        let mean = Double(conceptPercents.reduce(0, +)) / Double(conceptPercents.count)
        return Int(mean.rounded())
    }

    /// 底部总评：根据三维各自的平均掌握度生成一句话。纯模板、确定性（不调 LLM，保持一致性）。
    /// 维度均分 ≥1.5 视为"扎实"。
    public static func overallDiagnosis(rows: [(recall: Int, apply: Int, analyze: Int)]) -> String {
        guard !rows.isEmpty else { return "" }
        let n = Double(rows.count)
        let rAvg = Double(rows.reduce(0) { $0 + valid($1.recall) }) / n
        let aAvg = Double(rows.reduce(0) { $0 + valid($1.apply) }) / n
        let anAvg = Double(rows.reduce(0) { $0 + valid($1.analyze) }) / n
        let dims: [(String, Double)] = [("复述", rAvg), ("举例", aAvg), ("辨析", anAvg)]
        guard let weakest = dims.min(by: { $0.1 < $1.1 }),
              let strongest = dims.max(by: { $0.1 < $1.1 }) else { return "" }
        if weakest.1 >= 1.5 { return "整体掌握扎实。" }
        if strongest.1 >= 1.5 { return "\(weakest.0)层偏弱，\(strongest.0)没问题。" }
        return "\(weakest.0)层偏弱，需要再过一遍。"
    }

    private static func valid(_ v: Int) -> Int { (0...2).contains(v) ? v : 0 }
}
