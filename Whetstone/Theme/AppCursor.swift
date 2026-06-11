import AppKit
import SwiftUI

extension View {
    /// Declares an AppKit cursor rect for SwiftUI surfaces that sit above
    /// AppKit views. This prevents an underlying NSTextView cursor from
    /// leaking through overlays such as inline Ask cards.
    func appCursor(_ cursor: NSCursor) -> some View {
        background(AppCursorRect(cursor: cursor).allowsHitTesting(false))
    }
}

private struct AppCursorRect: NSViewRepresentable {
    let cursor: NSCursor

    func makeNSView(context: Context) -> CursorRectView {
        let view = CursorRectView()
        view.cursor = cursor
        return view
    }

    func updateNSView(_ nsView: CursorRectView, context: Context) {
        nsView.cursor = cursor
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

private final class CursorRectView: NSView {
    var cursor: NSCursor = .arrow {
        didSet { window?.invalidateCursorRects(for: self) }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: cursor)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.invalidateCursorRects(for: self)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        window?.invalidateCursorRects(for: self)
    }
}
