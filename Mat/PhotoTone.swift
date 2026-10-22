import SwiftUI
import UIKit

/// A bevel core colour taken from the photo: a softened version of its most prominent hue, the way
/// a framer picks a coloured core that echoes the picture rather than competing with it.
struct PhotoTone {
    let core: Color

    init(image: UIImage) {
        if let dominant = Self.dominantHue(of: image) {
            core = Color(hue: dominant.hue, saturation: min(dominant.saturation, 0.6) * 0.85, brightness: 0.62)
        } else {
            core = Color(white: 0.45)
        }
    }

    /// Hue and saturation of the strongest colour, or nil if the photo is essentially grey.
    private static func dominantHue(of image: UIImage) -> (hue: Double, saturation: Double)? {
        guard let cg = image.cgImage else { return nil }
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drew = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drew else { return nil }

        // Weight each pixel by how colourful and bright it is, in 15° hue buckets.
        let buckets = 24
        var weight = [Double](repeating: 0, count: buckets)
        var hueSum = [Double](repeating: 0, count: buckets)
        var saturationSum = [Double](repeating: 0, count: buckets)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[i]) / 255, g = Double(pixels[i + 1]) / 255, b = Double(pixels[i + 2]) / 255
            let high = max(r, g, b), delta = high - min(r, g, b)
            guard high > 0.12, delta > 0.06 else { continue }
            var hue: Double
            if high == r {
                hue = (g - b) / delta
            } else if high == g {
                hue = (b - r) / delta + 2
            } else {
                hue = (r - g) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
            let saturation = delta / high
            let w = saturation * high
            let k = min(Int(hue * Double(buckets)), buckets - 1)
            weight[k] += w
            hueSum[k] += hue * w
            saturationSum[k] += saturation * w
        }

        // Count neighbouring buckets at half weight, so a colour split across a boundary still wins.
        let score = (0..<buckets).map {
            weight[$0] + 0.5 * (weight[($0 + buckets - 1) % buckets] + weight[($0 + 1) % buckets])
        }
        guard let best = score.indices.max(by: { score[$0] < score[$1] }),
              weight[best] > Double(side * side) * 0.02 else { return nil }
        return (hueSum[best] / weight[best], saturationSum[best] / weight[best])
    }
}
