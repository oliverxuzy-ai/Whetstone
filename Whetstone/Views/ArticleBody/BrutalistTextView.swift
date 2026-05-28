import AppKit
import SwiftUI

/// NSTextView subclass for the article body. Drives:
/// - Custom selection color (cream-sage bg, near-black text)
/// - Selection-action popover (anchored to first glyph rect, dismissed on
///   blur, deselect, or action click)
final class BrutalistTextView: NSTextView {

    /// Invoked when the popover's Highlight action is selected.
    /// Caller is expected to insert a Highlight into SwiftData. The NSTextView
    /// re-renders when ArticleBodyView.updateNSView is called with the new
    /// highlights array.
    var onAddHighlight: ((NSRange, String) -> Void)?

    /// Invoked when the popover's "取消高亮" action is selected. Range is the
    /// rendered text range of the auto-selected highlight; selectedText is the
    /// text content (兜底用). Caller deletes the matching Highlight rows.
    var onRemoveHighlights: ((NSRange, String) -> Void)?

    private var popoverWindow: NSPanel?
    private var pendingPopoverWorkItem: DispatchWorkItem?
    /// One-shot: 下一次 showPopoverIfSelection 应该显示"取消高亮"动作集而不是
    /// 默认的"高亮"动作集。Set by mouseDown 单击命中现有高亮时,read+reset 在 popover 弹出时。
    private var pendingPopoverIsRemove: Bool = false
    /// Local NSEvent monitor used while the popover is shown — catches
    /// outside-panel clicks so we can dismiss without waiting for a
    /// selection-change notification (which won't fire if the user clicks
    /// outside the textview entirely).
    private var clickMonitor: Any?

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        isEditable = false
        isSelectable = true
        isRichText = true
        drawsBackground = false
        allowsUndo = false
        usesFindBar = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        smartInsertDeleteEnabled = false
        textContainerInset = .zero
        textContainer?.lineFragmentPadding = 0
        selectedTextAttributes = [
            .backgroundColor: NSColor(srgbRed: 0xB8/255.0, green: 0xC5/255.0, blue: 0xC5/255.0, alpha: 1),
            .foregroundColor: NSColor(srgbRed: 0x11/255.0, green: 0x11/255.0, blue: 0x11/255.0, alpha: 1)
        ]
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: self
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        pendingPopoverWorkItem?.cancel()
        if let m = clickMonitor { NSEvent.removeMonitor(m) }
    }

    /// When this textview is detached from its window (SwiftUI removing
    /// the parent view, e.g. user tapped Back to return to Library), close
    /// any popover panel — it was addChildWindow'd to the main NSWindow and
    /// would otherwise outlive the textview that anchors it.
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil { dismissPopover() }
    }

    // MARK: - Selection → popover

    /// NSTextView handles mouse tracking inside `mouseDown`; relying on a
    /// separate `mouseUp` override misses ordinary single-clicks. Capture the
    /// clicked highlight before AppKit moves the insertion point, then react
    /// after `super` finishes its tracking.
    override func mouseDown(with event: NSEvent) {
        let clickedHighlight = event.clickCount == 1 ? highlightRange(at: event) : nil
        super.mouseDown(with: event)

        let sel = selectedRange()
        // 单击 (无选区) 命中已有高亮 → auto-select 整段高亮 + 标记下一次 popover
        // 为 "取消高亮" 模式。拖选 / 普通点击空白处都走默认路径。
        if sel.length == 0, let h = clickedHighlight {
            pendingPopoverIsRemove = true
            setSelectedRange(h)
            schedulePopoverPresentation(after: 0.02)
            return
        }
        pendingPopoverIsRemove = false
        schedulePopoverPresentation(after: 0.02)
    }

    private func highlightRange(at event: NSEvent) -> NSRange? {
        guard let layout = layoutManager,
              let container = textContainer,
              let storage = textStorage,
              storage.length > 0 else { return nil }

        let viewPoint = convert(event.locationInWindow, from: nil)
        let containerPoint = NSPoint(
            x: viewPoint.x - textContainerOrigin.x,
            y: viewPoint.y - textContainerOrigin.y
        )

        var lineRange = NSRange(location: 0, length: 0)
        let glyphIndex = layout.glyphIndex(for: containerPoint, in: container)
        guard glyphIndex < layout.numberOfGlyphs else { return nil }

        let lineRect = layout.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
        guard lineRect.insetBy(dx: -4, dy: -4).contains(containerPoint) else { return nil }

        let charIndex = layout.characterIndexForGlyph(at: glyphIndex)
        return highlightRange(containing: charIndex)
    }

    /// 扫描 textStorage 找包含 charIdx 的高亮 backgroundColor 段。
    /// 用户高亮渲染时只设过 backgroundColor 这一种 storage 级属性 (selection 的
    /// 蓝色背景是 NSTextView 动态绘制的,不写进 storage),所以任意 backgroundColor
    /// 都视作高亮。
    private func highlightRange(containing charIdx: Int) -> NSRange? {
        guard let storage = textStorage else { return nil }
        let total = storage.length
        guard total > 0 else { return nil }
        // 单击末尾 (charIdx == total) 时不算命中任何字符;clamp 进字符空间。
        // 但要保留 charIdx-1 的检测 — 用户可能正好点在高亮最后一个字符的右边。
        let probes: [Int] = {
            var ps: [Int] = []
            if charIdx >= 0, charIdx < total { ps.append(charIdx) }
            if charIdx - 1 >= 0, charIdx - 1 < total { ps.append(charIdx - 1) }
            return ps
        }()
        for p in probes {
            var effective = NSRange(location: 0, length: 0)
            let attr = storage.attribute(.backgroundColor, at: p, effectiveRange: &effective)
            if attr != nil, effective.length > 0 {
                return effective
            }
        }
        return nil
    }

    /// Keyboard-driven selection (Shift+arrow, Cmd+A) also lands a popover at
    /// the end of the selection.
    override func keyUp(with event: NSEvent) {
        super.keyUp(with: event)
        // Only Shift-modified arrows + Cmd+A trigger a popover. Plain typing
        // can't happen on a read-only view.
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods.contains(.shift) || mods.contains(.command) {
            schedulePopoverPresentation(after: 0.02)
        }
    }

    @objc private func selectionDidChange(_ notification: Notification) {
        schedulePopoverPresentation()
    }

    private func schedulePopoverPresentation(after delay: TimeInterval = 0.12) {
        pendingPopoverWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if NSEvent.pressedMouseButtons != 0 {
                self.schedulePopoverPresentation(after: 0.08)
                return
            }
            self.showPopoverIfSelection()
        }
        pendingPopoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func showPopoverIfSelection() {
        let sel = selectedRange()
        guard sel.length > 0 else {
            dismissPopover()
            return
        }
        guard let layout = layoutManager, let container = textContainer else { return }
        let glyphRange = layout.glyphRange(forCharacterRange: sel, actualCharacterRange: nil)
        var rect = layout.boundingRect(forGlyphRange: glyphRange, in: container)
            .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
        // Guarantee a non-degenerate rect — NSPopover refuses to show against
        // a zero-size positioning rect.
        if rect.width < 1 { rect.size.width = 10 }
        if rect.height < 1 { rect.size.height = 10 }

        let selectedText = (string as NSString).substring(with: sel)

        guard let window = window else { return }
        popoverWindow?.close()

        let isRemoveMode = pendingPopoverIsRemove
        pendingPopoverIsRemove = false  // 消费 one-shot 标记
        let actions: [SelectionAction] = isRemoveMode ? [.removeHighlight, .ask] : [.highlight, .ask]

        let host = NSHostingController(rootView:
            SelectionActionPopover(actions: actions) { [weak self] action in
                guard let self = self else { return }
                switch action {
                case .highlight:
                    self.onAddHighlight?(sel, selectedText)
                case .removeHighlight:
                    self.onRemoveHighlights?(sel, selectedText)
                case .ask:
                    break
                }
                self.dismissPopover()
            }
        )
        // "取消高亮" 4 个汉字比 "Highlight" 略宽,稍微多给点宽度避免 SwiftUI 在
        // 固定 panel 里 clip。两按钮 + 1 分隔线: 默认 76*2+1=153; 中文模式给 86*2+1=173。
        let panelWidth: CGFloat = isRemoveMode ? 173 : 153
        let size = NSSize(width: panelWidth, height: 36)
        let windowRect = convert(rect, to: nil)
        let screenRect = window.convertToScreen(windowRect)
        let panelOrigin = NSPoint(
            x: screenRect.midX - size.width / 2,
            y: screenRect.maxY + 8
        )
        let panel = NSPanel(
            contentRect: NSRect(origin: panelOrigin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = true
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level.floating
        panel.contentViewController = host

        popoverWindow = panel
        window.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        startClickMonitor()
    }

    /// While the panel is shown, watch for in-app mouseDowns. Any click whose
    /// event window isn't the panel itself dismisses — covers clicks on the
    /// AIPane, the back/tab buttons, the sidebar after navigation, etc., none
    /// of which trigger a selectionDidChange in this textview.
    private func startClickMonitor() {
        stopClickMonitor()
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            if event.window !== self.popoverWindow {
                DispatchQueue.main.async { self.dismissPopover() }
            }
            return event
        }
    }

    private func stopClickMonitor() {
        if let m = clickMonitor {
            NSEvent.removeMonitor(m)
            clickMonitor = nil
        }
    }

    private func dismissPopover() {
        stopClickMonitor()
        pendingPopoverWorkItem?.cancel()
        pendingPopoverWorkItem = nil
        popoverWindow?.close()
        popoverWindow = nil
    }

    // MARK: - Focus ring suppression (brutalist — no system glow)

    override var focusRingType: NSFocusRingType {
        get { .none }
        set { _ = newValue }
    }
}
