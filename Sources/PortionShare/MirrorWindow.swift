import AppKit

/// The window you actually share. Meeting apps and browsers send this window's
/// pixels, so it always shows the capture at one window pixel per captured
/// pixel; that is also why it isn't resizable.
final class MirrorWindowController {
    let window: NSWindow
    private let hostView = LayerHostView()
    private var pixelSize = CGSize(width: 1280, height: 800)

    init() {
        window = MirrorWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered,
                              defer: false)
        window.isReleasedWhenClosed = false
        window.title = "PortionShare — share this window"
        window.contentView = hostView
        window.backgroundColor = .black
        // Dragging to a screen with a different scale changes the window's
        // pixel count, so re-fit it there.
        hostView.onBackingChange = { [weak self] in self?.fitToPixelSize() }
    }

    /// `pixelSize` is the capture's size in pixels. `region` is the captured
    /// area in global AppKit coordinates, which the window avoids.
    func present(layer: CALayer, pixelSize: CGSize, avoiding region: NSRect) {
        hostView.hostedLayer = layer
        self.pixelSize = pixelSize
        window.setFrame(placement(avoiding: region), display: true)
        if !window.isVisible {
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// Keeps the top-left corner in place.
    private func fitToPixelSize() {
        guard let screen = window.screen else { return }
        let size = frameSize(on: screen)
        let frame = window.frame
        window.setFrame(NSRect(x: frame.minX, y: frame.maxY - size.height,
                               width: size.width, height: size.height),
                        display: true)
    }

    private func frameSize(on screen: NSScreen) -> NSSize {
        let scale = screen.backingScaleFactor
        let content = NSRect(x: 0, y: 0,
                             width: pixelSize.width / scale, height: pixelSize.height / scale)
        return window.frameRect(forContentRect: content).size
    }

    /// Keeps the window off the screen you present from whenever there's
    /// another one. It takes a corner where it fits whole, else it hangs off
    /// a top corner so the overflow runs away from the region; window capture
    /// still includes the off-screen part.
    private func placement(avoiding region: NSRect) -> NSRect {
        let margin: CGFloat = 24
        let keepClear = region.insetBy(dx: -margin, dy: -margin)
        let otherScreens = NSScreen.screens.filter { !$0.frame.intersects(region) }
        let screens = otherScreens.isEmpty ? NSScreen.screens : otherScreens

        for screen in screens {
            let size = frameSize(on: screen)
            let area = screen.visibleFrame.insetBy(dx: margin, dy: margin)
            let corners = [
                NSPoint(x: area.maxX - size.width, y: area.minY),
                NSPoint(x: area.minX, y: area.minY),
                NSPoint(x: area.maxX - size.width, y: area.maxY - size.height),
                NSPoint(x: area.minX, y: area.maxY - size.height),
            ]
            for origin in corners {
                let frame = NSRect(origin: origin, size: size)
                if area.contains(frame) && !frame.intersects(keepClear) {
                    return frame
                }
            }
        }

        let area = screens[0].visibleFrame
        let size = frameSize(on: screens[0])
        // From another screen, anchor on the side facing the region; on the
        // region's own screen, on the side away from it.
        let regionIsRight = region.midX > area.midX
        let anchorRight = otherScreens.isEmpty ? !regionIsRight : regionIsRight
        return NSRect(x: anchorRight ? area.maxX - size.width : area.minX,
                      y: area.maxY - size.height,
                      width: size.width, height: size.height)
    }
}

/// AppKit shrinks a visible window that no longer fits its screen, which would
/// scale the capture down. Keep the size and let AppKit only move the window,
/// so the title bar stays reachable; window capture still includes the part
/// past the bottom edge.
private final class MirrorWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        let constrained = super.constrainFrameRect(frameRect, to: screen)
        return NSRect(x: constrained.minX, y: constrained.maxY - frameRect.height,
                      width: frameRect.width, height: frameRect.height)
    }
}

private final class LayerHostView: NSView {
    var onBackingChange: (() -> Void)?

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

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        onBackingChange?()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hostedLayer?.frame = bounds
        CATransaction.commit()
    }
}
