import Foundation

struct OKLab {
    var L: Double, a: Double, b: Double
    var chroma: Double { (a * a + b * b).squareRoot() }

    init(L: Double, a: Double, b: Double) { self.L = L; self.a = a; self.b = b }

    /// From gamma-encoded sRGB in 0...1.
    init(r: Double, g: Double, b bl: Double) {
        func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let r = lin(r), g = lin(g), bl = lin(bl)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * bl)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * bl)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * bl)
        L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    }

    private func linearRGB() -> (Double, Double, Double) {
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b
        let l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_
        return (
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        )
    }

    /// Gamma-encoded sRGB; chroma is reduced (hue and lightness kept) until the colour fits the gamut.
    func srgbInGamut() -> (r: Double, g: Double, b: Double) {
        func fits(_ c: OKLab) -> Bool {
            let (r, g, b) = c.linearRGB()
            return [r, g, b].allSatisfy { $0 >= -0.0005 && $0 <= 1.0005 }
        }
        var c = self
        if !fits(c) {
            var lo = 0.0, hi = 1.0
            for _ in 0..<18 {
                let mid = (lo + hi) / 2
                if fits(OKLab(L: L, a: a * mid, b: b * mid)) { lo = mid } else { hi = mid }
            }
            c = OKLab(L: L, a: a * lo, b: b * lo)
        }
        let (r, g, b) = c.linearRGB()
        func enc(_ v: Double) -> Double {
            let x = min(max(v, 0), 1)
            return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
        }
        return (enc(r), enc(g), enc(b))
    }
}
