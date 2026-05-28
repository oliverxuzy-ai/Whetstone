import AppKit
import SwiftUI
import WhetstoneCore

/// SwiftUI wrapper around BrutalistTextView. Sized via sizeThatFits so the
/// parent ScrollView in ReaderPane can scroll the whole body — the textview
/// itself does not scroll.
struct ArticleBodyView: NSViewRepresentable {
    let text: String
    let isLayoutEnhanced: Bool
    let highlights: [Highlight]
    var translation: [String]? = nil
    var showBilingual: Bool = false
    let onAddHighlight: (NSRange, String) -> Void
    var onRemoveHighlights: ((NSRange, String) -> Void)? = nil

    /// Holds the last memoization key so `updateNSView` can skip the O(n)
    /// attributed-string rebuild when no rendering input changed. SwiftUI
    /// invokes `updateNSView` very frequently (hover, scroll, unrelated state),
    /// so this avoids a main-thread rebuild + full attributed-string compare on
    /// every call.
    final class Coordinator {
        var lastKey: AttributedBodyKey?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> BrutalistTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)

        let tv = BrutalistTextView(frame: .zero, textContainer: container)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [NSView.AutoresizingMask.width]
        return tv
    }

    func updateNSView(_ tv: BrutalistTextView, context: Context) {
        // Cheap key over everything that affects rendering. A highlight's
        // signature is "charStart:charEnd:selectedText" (colorHex is excluded —
        // MarkdownToAttributed uses hardcoded highlight colors).
        let highlightSignatures = highlights.map { "\($0.charStart):\($0.charEnd):\($0.selectedText)" }
        let key = AttributedBodyKey(
            content: text,
            isEnhanced: isLayoutEnhanced,
            highlightSignatures: highlightSignatures,
            translation: translation,
            showBilingual: showBilingual
        )

        // Cache hit: skip the O(n) rebuild + the full attributed-string compare.
        // Still refresh the lightweight closures — they're cheap and capture
        // potentially-fresh SwiftUI state, and the textview already holds the
        // matching rendered content.
        if key == context.coordinator.lastKey {
            tv.onAddHighlight = onAddHighlight
            tv.onRemoveHighlights = onRemoveHighlights
            return
        }

        let attr = MarkdownToAttributed.attributedBody(
            from: text,
            isEnhanced: isLayoutEnhanced,
            highlights: highlights,
            translation: translation,
            showBilingual: showBilingual
        )
        tv.textStorage?.setAttributedString(attr)
        tv.onAddHighlight = onAddHighlight
        tv.onRemoveHighlights = onRemoveHighlights
        context.coordinator.lastKey = key
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: BrutalistTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 600
        nsView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        nsView.frame.size = NSSize(width: width, height: nsView.frame.height)
        guard let layout = nsView.layoutManager, let container = nsView.textContainer else {
            return CGSize(width: width, height: 0)
        }
        layout.ensureLayout(for: container)
        let used = layout.usedRect(for: container).size
        return CGSize(width: width, height: ceil(used.height))
    }
}
