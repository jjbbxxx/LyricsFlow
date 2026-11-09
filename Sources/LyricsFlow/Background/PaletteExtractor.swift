import AppKit
import SwiftUI

struct Palette {
    /// Display-ready colours for the moving blobs, most dominant first.
    let colors: [Color]
    /// Tiny copy of the cover, upscaled and blurred as the base layer.
    let base: CGImage?
    /// Darkening applied on top so white lyrics stay readable on any cover.
    let darken: Double
    let meanChroma: Double
}

/// Perceptual (OKLab) k-means palette; keeps colourful areas instead of averaging everything to grey-brown.
enum PaletteExtractor {
    private struct Cluster { var c: OKLab; var count = 0 }

    static func extract(from image: NSImage, k: Int = 6) -> Palette {
        let n = 40
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let pixels = downsample(cg, n)
        else { return Palette(colors: [.gray], base: nil, darken: 0.4, meanChroma: 0) }

        let points: [OKLab] = stride(from: 0, to: pixels.count, by: 4).map {
            OKLab(r: Double(pixels[$0]) / 255, g: Double(pixels[$0 + 1]) / 255, b: Double(pixels[$0 + 2]) / 255)
        }
        let weights = points.map { 0.25 + $0.chroma * 4 }
        let clusters = kmeans(points, weights, k: min(k, points.count))
        let total = Double(points.count)
        let meanL = points.reduce(0) { $0 + $1.L } / total
        let meanC = points.reduce(0) { $0 + $1.chroma } / total

        let ranked = clusters.filter { $0.count > 0 }.sorted {
            score($0, total) > score($1, total)
        }
        let colors = ranked.prefix(5).map { cl -> Color in
            let L = 0.24 + 0.46 * cl.c.L
            let s = 1.15
            let rgb = OKLab(L: L, a: cl.c.a * s, b: cl.c.b * s).srgbInGamut()
            return Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1)
        }
        let darken = min(max(0.04 + (meanL - 0.65) * 0.8, 0.04), 0.30)
        return Palette(colors: colors.isEmpty ? [.gray] : colors, base: smallCopy(cg, 64), darken: darken, meanChroma: meanC)
    }

    private static func score(_ c: Cluster, _ total: Double) -> Double {
        pow(Double(c.count) / total, 0.6) * (0.5 + c.c.chroma * 4)
    }

    private static func kmeans(_ pts: [OKLab], _ w: [Double], k: Int) -> [Cluster] {
        func d2(_ a: OKLab, _ b: OKLab) -> Double {
            let dl = a.L - b.L, da = a.a - b.a, db = a.b - b.b
            return dl * dl + da * da + db * db
        }
        let mean = OKLab(L: pts.reduce(0) { $0 + $1.L } / Double(pts.count),
                         a: pts.reduce(0) { $0 + $1.a } / Double(pts.count),
                         b: pts.reduce(0) { $0 + $1.b } / Double(pts.count))
        var centers = [pts.min { d2($0, mean) < d2($1, mean) }!]
        while centers.count < k {
            let next = pts.max { p, q in
                centers.map { d2(p, $0) }.min()! < centers.map { d2(q, $0) }.min()!
            }!
            centers.append(next)
        }
        var clusters = centers.map { Cluster(c: $0) }
        for _ in 0..<10 {
            var sums = Array(repeating: (l: 0.0, a: 0.0, b: 0.0, w: 0.0), count: k)
            var counts = Array(repeating: 0, count: k)
            for (i, p) in pts.enumerated() {
                let j = (0..<k).min { d2(p, clusters[$0].c) < d2(p, clusters[$1].c) }!
                sums[j].l += p.L * w[i]; sums[j].a += p.a * w[i]; sums[j].b += p.b * w[i]; sums[j].w += w[i]
                counts[j] += 1
            }
            for j in 0..<k where sums[j].w > 0 {
                clusters[j] = Cluster(c: OKLab(L: sums[j].l / sums[j].w, a: sums[j].a / sums[j].w, b: sums[j].b / sums[j].w), count: counts[j])
            }
        }
        return clusters
    }

    private static func downsample(_ cg: CGImage, _ n: Int) -> [UInt8]? {
        var buf = [UInt8](repeating: 0, count: n * n * 4)
        let ok = buf.withUnsafeMutableBytes { ptr -> Bool in
            guard let ctx = CGContext(data: ptr.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
            return true
        }
        return ok ? buf : nil
    }

    private static func smallCopy(_ cg: CGImage, _ n: Int) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
        return ctx.makeImage()
    }
}
