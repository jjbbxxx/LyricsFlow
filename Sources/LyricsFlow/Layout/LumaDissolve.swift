import AppKit
import CoreImage

/// Brightness-ordered dissolve between two covers. Each pixel of the new cover takes over from the old
/// one when a moving threshold passes its brightness, so bright areas change first and dark areas last,
/// like a flame front. Built from stock Core Image filters (no custom Metal kernel, so it builds with
/// Command Line Tools only).
final class LumaDissolve {
    /// Width of the soft edge, as a fraction of the brightness range. Larger means a smoother burn.
    static let softness = 0.5

    // Raw sRGB values, no linearisation: the threshold then sweeps the brightness range evenly.
    private static let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])

    private let from: CIImage
    private let to: CIImage
    private let luma: CIImage
    private let rect: CGRect

    init?(from: NSImage, to: NSImage, pixels: Int) {
        guard let a = Self.square(from, pixels), let b = Self.square(to, pixels) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: pixels, height: pixels)
        self.rect = rect
        self.from = a
        self.to = b
        // A slightly blurred grayscale copy keeps the front organic instead of following every fine detail.
        self.luma = b
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: Double(pixels) * 0.012])
            .cropped(to: rect)
    }

    /// `progress` runs 0...1 (already eased by the caller).
    func frame(progress: Double) -> CGImage? {
        let w = Self.softness
        let k = 1 / w
        let bias = (progress * (1 + w) - 1) / w
        let mask = luma
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: k, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: k, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: k, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: bias, y: bias, z: bias, w: 0),
            ])
            .applyingFilter("CIColorClamp")
        let out = to.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: from,
            kCIInputMaskImageKey: mask,
        ])
        return Self.context.createCGImage(out, from: rect)
    }

    private static func square(_ image: NSImage, _ pixels: Int) -> CIImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let ci = CIImage(cgImage: cg)
        let sx = CGFloat(pixels) / ci.extent.width, sy = CGFloat(pixels) / ci.extent.height
        return ci.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
    }
}
