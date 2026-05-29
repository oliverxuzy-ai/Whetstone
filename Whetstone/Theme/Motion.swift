import SwiftUI

/// Brutalist-editorial motion primitives. Three only — more would be dishonest.
///
/// - `flip`  : 瞬时状态反转(色彩反转 / 开关 / 聚焦标记)。linear 50ms。
/// - `drive` : 刚体位移(侧栏滑入滑出 / 面板硬推 / sheet 落入)。cubic-bezier(0.2,0,0,1),无 overshoot。
/// - flap    : split-flap 翻牌(标题/数字揭示),离散帧;按需在具体视图里用 KeyframeAnimator 实现,不放全局。
enum Motion {
    static let flip = Animation.linear(duration: 0.05)
    static let drive = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.18)
}
