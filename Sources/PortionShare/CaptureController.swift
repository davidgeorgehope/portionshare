import AVFoundation
import ScreenCaptureKit

/// Streams a rectangle of one display into an AVSampleBufferDisplayLayer.
final class CaptureController: NSObject, SCStreamOutput, SCStreamDelegate {
    let displayLayer = AVSampleBufferDisplayLayer()

    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "portionshare.capture")
    var onStopped: ((Error?) -> Void)?

    override init() {
        super.init()
        displayLayer.videoGravity = .resizeAspect
    }

    func start(display: SCDisplay, rectInDisplay: CGRect, scale: CGFloat,
               excluding app: SCRunningApplication?) async throws {
        let filter = app.map {
            SCContentFilter(display: display, excludingApplications: [$0], exceptingWindows: [])
        } ?? SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.sourceRect = rectInDisplay
        // Encoders (and Zoom) prefer even pixel dimensions.
        config.width = max(2, Int(rectInDisplay.width * scale) & ~1)
        config.height = max(2, Int(rectInDisplay.height * scale) & ~1)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.queueDepth = 5

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() {
        stream?.stopCapture { _ in }
        stream = nil
        displayLayer.flushAndRemoveImage()
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        guard let attachments = (CMSampleBufferGetSampleAttachmentsArray(
                  sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]])?.first,
              let statusRaw = attachments[.status] as? Int,
              SCFrameStatus(rawValue: statusRaw) == .complete else { return }

        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(sampleBuffer)
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.onStopped?(error)
        }
    }
}
