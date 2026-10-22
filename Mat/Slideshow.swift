import Photos
import SwiftUI

enum Orientation: Hashable {
    case landscape, portrait

    init(_ size: CGSize) {
        self = size.width >= size.height ? .landscape : .portrait
    }

    /// Near-square photos count for both orientations.
    func accepts(_ aspect: Double) -> Bool {
        self == .landscape ? aspect >= 0.9 : aspect <= 1.1
    }
}

struct Slide: Identifiable {
    let id = UUID()
    let photoID: String
    let image: UIImage
}

/// Shuffles through the chosen album, one deck per orientation, so every matching photo
/// is shown once before any repeats.
@MainActor
@Observable
final class Slideshow {
    enum State: Equatable { case starting, denied, noAlbum, empty, running }

    private(set) var state: State = .starting
    /// The visible photo is last; the one beneath it stays until the fade finishes.
    private(set) var slides: [Slide] = []

    @ObservationIgnored private var photos: [PhotoRef] = []
    @ObservationIgnored private var decks: [Orientation: [String]] = [:]
    @ObservationIgnored private var history: [String] = []
    @ObservationIgnored private var loadedAlbum: String?
    @ObservationIgnored private var libraryChanged = false
    @ObservationIgnored private var observer: LibraryObserver?

    /// Shows a photo straight away, then a new one every interval until cancelled.
    func run(settings: Settings, orientation: Orientation, pixels: CGSize, back: Bool) async {
        guard await ensureAccess() else { return }
        #if DEBUG
        await DebugSeed.runIfRequested(settings)
        #endif
        guard let albumID = settings.albumID else {
            state = .noAlbum
            return
        }
        var stepBack = back
        while !Task.isCancelled {
            if albumID != loadedAlbum || libraryChanged { load(albumID) }
            let started = Date()
            await show(orientation: orientation, pixels: pixels, back: stepBack, fade: settings.fade)
            stepBack = false
            guard state == .running else { return }
            let wait = settings.interval - Date().timeIntervalSince(started)
            do { try await Task.sleep(for: .seconds(max(wait, 1))) } catch { return }
        }
    }

    private func ensureAccess() async -> Bool {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard status == .authorized || status == .limited else {
            state = .denied
            return false
        }
        if observer == nil {
            observer = LibraryObserver { [weak self] in self?.libraryChanged = true }
        }
        return true
    }

    private func load(_ albumID: String) {
        photos = PhotoLibrary.photos(inAlbum: albumID)
        if albumID != loadedAlbum {
            decks = [:]
            history = []
        } else {
            let present = Set(photos.map(\.id))
            decks = decks.mapValues { $0.filter(present.contains) }
            history = history.filter(present.contains)
        }
        loadedAlbum = albumID
        libraryChanged = false
    }

    private func show(orientation: Orientation, pixels: CGSize, back: Bool, fade: Double) async {
        let pool = photos.filter { orientation.accepts($0.aspect) }.map(\.id)
        guard !pool.isEmpty else {
            state = .empty
            slides = []
            return
        }
        state = .running
        // A photo can fail to load (deleted, or iCloud unreachable); try a few before giving up for this turn.
        for _ in 0..<5 {
            guard let id = back ? previousID(in: pool) : nextID(in: pool, orientation: orientation) else { return }
            guard let image = await PhotoLibrary.image(id: id, pixels: pixels) else { continue }
            guard !Task.isCancelled else { return }
            if !back {
                history.append(id)
                if history.count > 200 { history.removeFirst(history.count - 200) }
            }
            let slide = Slide(photoID: id, image: image)
            withAnimation(.easeInOut(duration: fade)) { slides.append(slide) }
            Task {
                try? await Task.sleep(for: .seconds(fade + 0.25))
                if let i = slides.firstIndex(where: { $0.id == slide.id }) { slides.removeFirst(i) }
            }
            return
        }
    }

    private func nextID(in pool: [String], orientation: Orientation) -> String? {
        var deck = decks[orientation] ?? []
        if deck.isEmpty {
            deck = pool.shuffled()
            // Cards are dealt from the end; don't open a new round with the photo just shown.
            if deck.count > 1, deck.last == history.last { deck.swapAt(0, deck.count - 1) }
        }
        let id = deck.popLast()
        decks[orientation] = deck
        return id
    }

    /// Drops the current photo from the history and returns the one before it that fits this orientation.
    private func previousID(in pool: [String]) -> String? {
        let fits = Set(pool)
        guard let i = history.dropLast().lastIndex(where: fits.contains) else { return nil }
        history.removeSubrange((i + 1)...)
        return history[i]
    }
}
