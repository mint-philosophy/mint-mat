import SwiftUI
import UIKit

struct RootView: View {
    @State private var settings = Settings()
    @State private var slideshow = Slideshow()
    @State private var showSettings = false
    @State private var isNight = false
    @State private var wakeUntil = Date.distantPast
    /// Bumped to restart the slideshow loop at once (a swipe, or returning from the Settings app).
    @State private var restart = 0
    @State private var stepBack = false
    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase

    private struct LoopKey: Hashable {
        let album: String?
        let width: Int
        let height: Int
        let paused: Bool
        let restart: Int
    }

    var body: some View {
        GeometryReader { geo in
            let screen = geo.size
            let window = MatGeometry.window(in: screen, settings: settings)
            ZStack {
                settings.matColour.color(for: nil)
                // Each slide carries its own mat and bevel, so a mat taken from the photo crossfades with it.
                ForEach(slideshow.slides) { slide in
                    SlideView(
                        slide: slide, screen: screen, window: window,
                        mat: settings.matColour.color(for: slide.tone),
                        bevel: settings.bevel.core(for: settings.matColour, tone: slide.tone),
                        bevelWidth: MatGeometry.bevelWidth(screen: screen),
                        crop: settings.cropMode
                    )
                    .transition(.asymmetric(insertion: .opacity, removal: .identity))
                }
                StatusMessage(state: slideshow.state, orientation: Orientation(screen), settings: settings)
                Color.black
                    .opacity(isNight ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { tapped() }
            .gesture(DragGesture(minimumDistance: 30).onEnded(swiped))
            .task(id: LoopKey(album: settings.albumID, width: Int(screen.width), height: Int(screen.height), paused: isNight, restart: restart)) {
                guard !isNight, screen.width > 0, screen.height > 0 else { return }
                let back = stepBack
                stepBack = false
                let pixels = CGSize(width: screen.width * displayScale, height: screen.height * displayScale)
                await slideshow.run(settings: settings, orientation: Orientation(screen), pixels: pixels, back: back)
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .trailing) {
            if showSettings {
                SettingsPanel(settings: settings) {
                    withAnimation(.easeInOut(duration: 0.25)) { showSettings = false }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .task {
            #if DEBUG
            Task { await DebugSeed.rotateIfRequested() }
            #endif
            while !Task.isCancelled {
                updateNight()
                try? await Task.sleep(for: .seconds(20))
            }
        }
        .onChange(of: settings.nightEnabled) { updateNight() }
        .onChange(of: settings.nightStart) { updateNight() }
        .onChange(of: settings.nightEnd) { updateNight() }
        .onChange(of: slideshow.state) { _, state in
            if state == .noAlbum { withAnimation { showSettings = true } }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Keep the screen on while Mat is in front.
            UIApplication.shared.isIdleTimerDisabled = phase == .active
            if phase == .active, slideshow.state == .denied { restart += 1 }
        }
    }

    private func tapped() {
        if isNight {
            wakeUntil = Date.now.addingTimeInterval(15 * 60)
            updateNight()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { showSettings.toggle() }
        }
    }

    private func swiped(_ value: DragGesture.Value) {
        let dx = value.translation.width
        guard !isNight, abs(dx) > 80, abs(dx) > abs(value.translation.height) else { return }
        stepBack = dx > 0
        restart += 1
    }

    private func updateNight() {
        let night = settings.isNight(at: .now) && Date.now >= wakeUntil
        guard night != isNight else { return }
        withAnimation(.easeInOut(duration: 4)) { isNight = night }
    }
}

/// One photo on its own full-screen mat, so a new slide fading in covers the old one completely.
private struct SlideView: View {
    let slide: Slide
    let screen: CGSize
    let window: CGRect
    let mat: Color
    let bevel: Color?
    let bevelWidth: CGFloat
    let crop: CropMode

    var body: some View {
        ZStack {
            mat
            Image(uiImage: slide.image)
                .resizable()
                .aspectRatio(contentMode: crop == .fill ? .fill : .fit)
                .frame(width: window.width, height: window.height)
                .clipped()
                .position(x: window.midX, y: window.midY)
            if let bevel {
                BevelView(window: window, width: bevelWidth, core: bevel)
            }
        }
        .frame(width: screen.width, height: screen.height)
    }
}

private struct StatusMessage: View {
    let state: Slideshow.State
    let orientation: Orientation
    let settings: Settings

    var body: some View {
        Group {
            switch state {
            case .starting, .running:
                EmptyView()
            case .denied:
                VStack(spacing: 16) {
                    Text("Mat needs access to your photos.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            case .noAlbum:
                Text("Choose an album to begin.")
            case .empty:
                Text("No \(orientation == .landscape ? "landscape" : "portrait") photos in “\(settings.albumTitle ?? "this album")”.")
            }
        }
        .font(.title3)
        .foregroundStyle(settings.matColour.textColor)
    }
}
