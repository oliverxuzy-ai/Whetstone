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
        let attr = MarkdownToAttributed.attributedBody(
            from: text,
            isEnhanced: isLayoutEnhanced,
            highlights: highlights,
            translation: translation,
            showBilingual: showBilingual
        )
        if tv.attributedString() != attr {
            tv.textStorage?.setAttributedString(attr)
        }
        tv.onAddHighlight = onAddHighlight
        tv.onRemoveHighlights = onRemoveHighlights
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
