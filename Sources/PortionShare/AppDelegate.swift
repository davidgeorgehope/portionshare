import AppKit
import ScreenCaptureKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var selection: SelectionController?
    private var capture: CaptureController?
    private var mirror: MirrorWindowController?
    private var border: BorderWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        beginSelection()
    }

    // MARK: - Flow

    @objc func beginSelection() {
        capture?.stop()
        capture = nil
        border?.orderOut(nil)
        border = nil

        selection = SelectionController { [weak self] cgRect in
            guard let self else { return }
            self.selection = nil
            if let cgRect {
                self.startSharing(region: cgRect)
            } else if self.mirror == nil {
                // Cancelled before anything was ever shared: nothing to do.
                NSApp.terminate(nil)
            }
        }
        selection?.begin()
    }

    private func startSharing(region cgRect: CGRect) {
        if mirror == nil {
            let controller = MirrorWindowController()
            controller.window.delegate = self
            mirror = controller
        }

        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(
                    true, onScreenWindowsOnly: true)

                let center = CGPoint(x: cgRect.midX, y: cgRect.midY)
                guard let display = content.displays.first(where: {
                    CGDisplayBounds($0.displayID).contains(center)
                }) else {
                    throw PortionShareError.noDisplayForSelection
                }

                let displayBounds = CGDisplayBounds(display.displayID)
                let rectInDisplay = cgRect
                    .intersection(displayBounds)
                    .offsetBy(dx: -displayBounds.origin.x, dy: -displayBounds.origin.y)

                // Exclude our own windows (mirror + region border) so the
                // stream never captures itself.
                let ownPID = ProcessInfo.processInfo.processIdentifier
                let ownWindows = content.windows.filter {
                    $0.owningApplication?.processID == ownPID
                }

                let controller = CaptureController()
                controller.onStopped = { [weak self] error in
                    self?.captureStopped(error: error)
                }
                try await controller.start(display: display,
                                           rectInDisplay: rectInDisplay,
                                           scale: backingScale(for: display),
                                           excluding: ownWindows)
                capture = controller
                mirror?.present(layer: controller.displayLayer, contentSize: rectInDisplay.size)
                border = BorderWindow(around: cgRect)
                NSApp.activate(ignoringOtherApps: true)
            } catch {
                presentFailure(error)
            }
        }
    }

    private func captureStopped(error: Error?) {
        guard capture != nil else { return }
        capture = nil
        border?.orderOut(nil)
        border = nil
        if let error {
            presentFailure(error)
        }
    }

    private func presentFailure(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not capture the screen"
        alert.informativeText = error.localizedDescription
            + "\n\nIf this is the first launch, grant Screen Recording access in "
            + "System Settings → Privacy & Security → Screen Recording, then reopen PortionShare."
        alert.addButton(withTitle: "Quit")
        alert.runModal()
        NSApp.terminate(nil)
    }

    private func backingScale(for display: SCDisplay) -> CGFloat {
        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
                .uint32Value == display.displayID
        }
        return screen?.backingScaleFactor ?? 2
    }

    // MARK: - Menu

    private func buildMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Select New Region",
                        action: #selector(beginSelection),
                        keyEquivalent: "r")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit PortionShare",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    // MARK: - NSWindowDelegate (mirror window)

    func windowWillClose(_ notification: Notification) {
        capture?.stop()
        NSApp.terminate(nil)
    }
}

enum PortionShareError: LocalizedError {
    case noDisplayForSelection

    var errorDescription: String? {
        switch self {
        case .noDisplayForSelection:
            return "The selected region is not on any active display."
        }
    }
}
