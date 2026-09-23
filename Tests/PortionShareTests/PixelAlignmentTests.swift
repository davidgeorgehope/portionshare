import CoreGraphics
import Testing
@testable import PortionShare

struct PixelAlignmentTests {
    private let dragSelection = CGRect(x: 100.3711, y: 50.6133, width: 801.0977, height: 500.7109)

    @Test func snapsDragSelectionsToWholeRetinaPixels() {
        let rect = Coordinates.pixelAligned(dragSelection, scale: 2)
        #expect(rect == CGRect(x: 100.5, y: 50.5, width: 801, height: 500))
    }

    @Test func snapsDragSelectionsToWholePixelsWithEvenSizeAt1x() {
        let rect = Coordinates.pixelAligned(dragSelection, scale: 1)
        #expect(rect == CGRect(x: 100, y: 51, width: 800, height: 500))
    }

    @Test func leavesAlignedRectsUnchanged() {
        let rect = CGRect(x: 10, y: 20, width: 640, height: 400)
        #expect(Coordinates.pixelAligned(rect, scale: 2) == rect)
    }

    @Test func neverShrinksBelowTwoPixels() {
        let rect = Coordinates.pixelAligned(CGRect(x: 0, y: 0, width: 0.3, height: 0.3), scale: 2)
        #expect(rect.size == CGSize(width: 1, height: 1))
    }
}
