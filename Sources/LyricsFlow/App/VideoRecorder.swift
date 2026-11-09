import AppKit
import AVFoundation

/// Records the app's own window at 30 fps to an H.264 .mov (own-window capture needs no screen permission).
enum VideoRecorder {
    static func record(_ window: NSWindow, to path: String, seconds: Double, done: @escaping () -> Void) {
        guard let first = ShotController.image(of: window) else { fputs("capture failed\n", stderr); done(); return }
        let w = first.width & ~1, h = first.height & ~1
        try? FileManager.default.removeItem(atPath: path)
        guard let writer = try? AVAssetWriter(outputURL: URL(fileURLWithPath: path), fileType: .mov) else { done(); return }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let fps = 30.0
        let total = Int(seconds * fps)
        var frame = 0
        let start = Date()
        let timer = Timer.scheduledTimer(withTimeInterval: 1 / fps, repeats: true) { t in
            if frame >= total {
                t.invalidate()
                input.markAsFinished()
                writer.finishWriting { done() }
                return
            }
            guard input.isReadyForMoreMediaData, let img = ShotController.image(of: window),
                  let pool = adaptor.pixelBufferPool else { return }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
            guard let buf = pb else { return }
            CVPixelBufferLockBaseAddress(buf, [])
            if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: w, height: h, bitsPerComponent: 8,
                                   bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
                ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
            CVPixelBufferUnlockBaseAddress(buf, [])
            let pts = CMTime(seconds: Date().timeIntervalSince(start), preferredTimescale: 600)
            adaptor.append(buf, withPresentationTime: pts)
            frame += 1
        }
        RunLoop.main.add(timer, forMode: .common)
    }
}
