import SwiftUI

/// The cut edge of the mat: a thin band of core around the opening with each side shaded as if
/// lit from the upper left, and the faint shadow the board's thickness casts onto the photo.
struct BevelView: View {
    let window: CGRect
    let width: CGFloat
    let core: Color

    var body: some View {
        Canvas { context, _ in
            let w = window
            let o = window.insetBy(dx: -width, dy: -width)

            // Lay the whole band in core first so the mitre seams blend core into core, not into the mat.
            var band = Path(o)
            band.addRect(w)
            context.fill(band, with: .color(core), style: FillStyle(eoFill: true))

            func side(_ corners: [CGPoint], brightness: Double) {
                guard brightness < 1 else { return }
                var path = Path()
                path.addLines(corners)
                path.closeSubpath()
                context.fill(path, with: .color(.black.opacity(1 - brightness)))
            }

            // Each bevel slopes down into the opening, so the bottom one faces up toward the
            // light and the top one faces away from it.
            side([CGPoint(x: o.minX, y: o.minY), CGPoint(x: o.maxX, y: o.minY),
                  CGPoint(x: w.maxX, y: w.minY), CGPoint(x: w.minX, y: w.minY)], brightness: 0.74)
            side([CGPoint(x: o.minX, y: o.minY), CGPoint(x: w.minX, y: w.minY),
                  CGPoint(x: w.minX, y: w.maxY), CGPoint(x: o.minX, y: o.maxY)], brightness: 0.84)
            side([CGPoint(x: o.maxX, y: o.minY), CGPoint(x: o.maxX, y: o.maxY),
                  CGPoint(x: w.maxX, y: w.maxY), CGPoint(x: w.maxX, y: w.minY)], brightness: 0.93)
            side([CGPoint(x: o.minX, y: o.maxY), CGPoint(x: w.minX, y: w.maxY),
                  CGPoint(x: w.maxX, y: w.maxY), CGPoint(x: o.maxX, y: o.maxY)], brightness: 1)

            let depth = width * 0.7
            context.fill(
                Path(CGRect(x: w.minX, y: w.minY, width: w.width, height: depth)),
                with: .linearGradient(Gradient(colors: [.black.opacity(0.35), .clear]),
                                      startPoint: CGPoint(x: 0, y: w.minY), endPoint: CGPoint(x: 0, y: w.minY + depth)))
            context.fill(
                Path(CGRect(x: w.minX, y: w.minY, width: depth, height: w.height)),
                with: .linearGradient(Gradient(colors: [.black.opacity(0.22), .clear]),
                                      startPoint: CGPoint(x: w.minX, y: 0), endPoint: CGPoint(x: w.minX + depth, y: 0)))
        }
        .allowsHitTesting(false)
    }
}
