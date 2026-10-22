import SwiftUI

enum MatColour: String, CaseIterable, Identifiable {
    case black, charcoal, offWhite

    var id: String { rawValue }

    var name: String {
        switch self {
        case .black: "Black"
        case .charcoal: "Charcoal"
        case .offWhite: "Off-white"
        }
    }

    var color: Color {
        switch self {
        case .black: .black
        case .charcoal: Color(red: 0.12, green: 0.12, blue: 0.12)
        case .offWhite: Color(red: 0.95, green: 0.94, blue: 0.91)
        }
    }

    /// Colour for the occasional status message drawn on the mat.
    var textColor: Color {
        self == .offWhite ? .black.opacity(0.45) : .white.opacity(0.45)
    }
}

enum CropMode: String, CaseIterable, Identifiable {
    case fill, fit
    var id: String { rawValue }
}

/// Everything the viewer can change, saved to UserDefaults as it changes.
@Observable
final class Settings {
    static let intervals: [Double] = [15, 30, 60, 120, 300, 600, 1800, 3600]
    static let fades: [Double] = [1, 2, 3, 5]
    static let marginStops: [Double] = [0.5, 0.75, 1, 1.25, 1.5, 2]
    static let marginRange: ClosedRange<Double> = 0.25...2.5

    @ObservationIgnored private let defaults = UserDefaults.standard

    var albumID: String? { didSet { defaults.set(albumID, forKey: "albumID") } }
    var albumTitle: String? { didSet { defaults.set(albumTitle, forKey: "albumTitle") } }
    var interval: Double { didSet { defaults.set(interval, forKey: "interval") } }
    var fade: Double { didSet { defaults.set(fade, forKey: "fade") } }
    var marginInches: Double { didSet { defaults.set(marginInches, forKey: "marginInches") } }
    var bottomWeighted: Bool { didSet { defaults.set(bottomWeighted, forKey: "bottomWeighted") } }
    var matColour: MatColour { didSet { defaults.set(matColour.rawValue, forKey: "matColour") } }
    var cropMode: CropMode { didSet { defaults.set(cropMode.rawValue, forKey: "cropMode") } }
    var nightEnabled: Bool { didSet { defaults.set(nightEnabled, forKey: "nightEnabled") } }
    /// Minutes after midnight.
    var nightStart: Int { didSet { defaults.set(nightStart, forKey: "nightStart") } }
    var nightEnd: Int { didSet { defaults.set(nightEnd, forKey: "nightEnd") } }

    init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            "interval": 60.0,
            "fade": 2.0,
            "marginInches": 1.0,
            "bottomWeighted": false,
            "matColour": MatColour.black.rawValue,
            "cropMode": CropMode.fill.rawValue,
            "nightEnabled": true,
            "nightStart": 23 * 60,
            "nightEnd": 7 * 60,
        ])
        albumID = d.string(forKey: "albumID")
        albumTitle = d.string(forKey: "albumTitle")
        interval = d.double(forKey: "interval")
        fade = d.double(forKey: "fade")
        marginInches = d.double(forKey: "marginInches")
        bottomWeighted = d.bool(forKey: "bottomWeighted")
        matColour = MatColour(rawValue: d.string(forKey: "matColour") ?? "") ?? .black
        cropMode = CropMode(rawValue: d.string(forKey: "cropMode") ?? "") ?? .fill
        nightEnabled = d.bool(forKey: "nightEnabled")
        nightStart = d.integer(forKey: "nightStart")
        nightEnd = d.integer(forKey: "nightEnd")
    }

    /// Pulls a dragged margin onto a stop when it comes within a sixteenth of an inch,
    /// otherwise rounds to the nearest twentieth.
    static func snappedMargin(_ inches: Double) -> Double {
        if let stop = marginStops.first(where: { abs($0 - inches) < 0.0625 }) { return stop }
        return (inches * 20).rounded() / 20
    }

    func isNight(at date: Date) -> Bool {
        guard nightEnabled, nightStart != nightEnd else { return false }
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return nightStart < nightEnd
            ? (m >= nightStart && m < nightEnd)
            : (m >= nightStart || m < nightEnd)
    }
}

enum MatGeometry {
    /// iPads draw at 2x. Most have 264 pixels per inch (132 points); the iPad mini has 326 (163 points).
    static func pointsPerInch(screen: CGSize) -> CGFloat {
        min(screen.width, screen.height) == 744 ? 163 : 132
    }

    /// The opening in the mat, in screen points.
    static func window(in screen: CGSize, settings: Settings) -> CGRect {
        let inch = pointsPerInch(screen: screen)
        let m = settings.marginInches * inch
        let extra = settings.bottomWeighted ? 0.25 * inch : 0
        return CGRect(
            x: m,
            y: m,
            width: max(screen.width - 2 * m, 1),
            height: max(screen.height - 2 * m - extra, 1)
        )
    }
}
