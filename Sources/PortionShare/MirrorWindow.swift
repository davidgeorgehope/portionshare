import AppKit

/// The window you actually share in Zoom. Hosts the live capture layer and
/// keeps the selection's aspect ratio when resized.
final class MirrorWindowController {
    let window: NSWindow
    private let hostView = LayerHostView()

    init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered,
                          defer: false)
        window.isReleasedWhenClosed = false
        window.title = "PortionShare — share this window in Zoom"
        window.contentView = hostView
        window.backgroundColor = .black
        window.minSize = NSSize(width: 200, height: 120)
    }

    func present(layer: CALayer, contentSize: CGSize) {
        hostView.hostedLayer = layer
        window.contentAspectRatio = contentSize

        // Fit the initial window to the selection, capped so it stays manageable.
        let maxWidth: CGFloat = 960
        let maxHeight: CGFloat = 640
        let fit = min(1, min(maxWidth / contentSize.width, maxHeight / contentSize.height))
        let size = NSSize(width: contentSize.width * fit, height: contentSize.height * fit)
        window.setContentSize(size)

        if !window.isVisible {
            positionAwayFromCenter()
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func positionAwayFromCenter() {
        guard let screen = NSScreen.main else {
            window.center()
            return
        }
        // Bottom-right corner, so it is less likely to sit on top of the
        // region being captured.
        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.maxX - window.frame.width - 24,
                             y: visible.minY + 24)
        window.setFrameOrigin(origin)
    }
}

private final class LayerHostView: NSView {
    var hostedLayer: CALayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            if let hostedLayer {
                layer?.addSublayer(hostedLayer)
                needsLayout = true
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hostedLayer?.frame = bounds
        CATransaction.commit()
    }
}
