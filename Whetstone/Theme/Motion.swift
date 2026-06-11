import SwiftUI

/// V2.0 动效三 token(spring 体系,WWDC23 范式)。
///
/// - `state`: 状态切换(hover 浮现 / 选中 / 淡入淡出)。smooth = 零弹。
/// - `move` : 位移与尺寸(栏折叠 / 卡片展开)。snappy = 微弹的现代 Apple 手感。
/// - `ai`   : 仅 AI 时刻(涌入 / 出分 / 气泡 morph)。bouncy = 新奇预算的支出处。
///
/// 规则:正文区滚动之外零自发动效;自动行为(进度)用 linear 不用 spring;
/// 自定义动画必须接 `accessibilityReduceMotion` 降级(Phase E 统一接入)。
enum Motion {
    static let state = Animation.smooth(duration: 0.18)
    static let move = Animation.snappy(duration: 0.32)
    static let ai = Animation.bouncy(duration: 0.45, extraBounce: 0.05)
}
