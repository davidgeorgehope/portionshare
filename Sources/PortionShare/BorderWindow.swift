import AppKit

/// Click-through outline drawn around the shared region so you can see what
/// is being broadcast. Belongs to this app's process, so the capture filter
/// excludes it from the stream automatically.
final class BorderWindow: NSWindow {
    init(around cgGlobalRect: CGRect) {
        let inset: CGFloat = -3
        let frame = Coordinates.nsRect(fromGlobalCG: cgGlobalRect).insetBy(dx: inset, dy: inset)
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = BorderView(frame: NSRect(origin: .zero, size: frame.size))
        orderFrontRegardless()
    }
}

private final class BorderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(rect: bounds.insetBy(dx: 1.5, dy: 1.5))
        path.lineWidth = 3
        NSColor.systemOrange.setStroke()
        path.stroke()
    }
}
