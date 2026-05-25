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

    private var popoverWindow: NSPanel?
    private var pendingPopoverWorkItem: DispatchWorkItem?

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
    }

    // MARK: - Selection → popover

    /// Mouse/key hooks keep the popover responsive, while selection-change
    /// notifications below cover AppKit paths that do not reliably land here.
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        schedulePopoverPresentation(after: 0.02)
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

        let host = NSHostingController(rootView:
            SelectionActionPopover(actions: [.highlight, .ask]) { [weak self] action in
                guard let self = self else { return }
                switch action {
                case .highlight:
                    self.onAddHighlight?(sel, selectedText)
                case .ask:
                    break
                }
                self.dismissPopover()
            }
        )
        let size = NSSize(width: 153, height: 36)
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
    }

    private func dismissPopover() {
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
