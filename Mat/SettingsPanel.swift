import SwiftUI

/// Slides in from the right so the mat and photo stay visible while the margin is adjusted.
struct SettingsPanel: View {
    @Bindable var settings: Settings
    let close: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Photos") {
                    NavigationLink {
                        AlbumList(settings: settings)
                    } label: {
                        LabeledContent("Album", value: settings.albumTitle ?? "None")
                    }
                    Picker("Each photo for", selection: $settings.interval) {
                        ForEach(Settings.intervals, id: \.self) { Text(durationLabel($0)).tag($0) }
                    }
                    Picker("Fade", selection: $settings.fade) {
                        ForEach(Settings.fades, id: \.self) { Text("\(Int($0)) s").tag($0) }
                    }
                }

                Section("Mat") {
                    marginControl
                    Toggle("Deeper bottom margin", isOn: $settings.bottomWeighted)
                    Picker("Colour", selection: $settings.matColour) {
                        ForEach(MatColour.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Photos", selection: $settings.cropMode) {
                        Text("Fill the opening").tag(CropMode.fill)
                        Text("Fit inside it").tag(CropMode.fit)
                    }
                }

                Section {
                    Toggle("Turn off at night", isOn: $settings.nightEnabled)
                    if settings.nightEnabled {
                        DatePicker("From", selection: time(\.nightStart), displayedComponents: .hourAndMinute)
                        DatePicker("Until", selection: time(\.nightEnd), displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Night")
                } footer: {
                    Text("Tap the screen at night to wake it for 15 minutes.")
                }

                Section {
                } footer: {
                    Text("Swipe left or right to change photo. To keep the iPad in Mat, turn on Guided Access in Settings › Accessibility, then triple-click the top button.")
                }
            }
            .navigationTitle("Mat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: close)
                }
            }
        }
        .frame(width: 400)
        .frame(maxHeight: 760)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 30)
        .padding(24)
    }

    private var marginControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Margin")
                Spacer()
                Text(String(format: "%.2f in", settings.marginInches))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { settings.marginInches },
                    set: { settings.marginInches = Settings.snappedMargin($0) }
                ),
                in: Settings.marginRange
            )
            HStack(spacing: 8) {
                ForEach(Settings.marginStops, id: \.self) { stop in
                    Button(inchLabel(stop)) { settings.marginInches = stop }
                        .buttonStyle(.bordered)
                        .tint(stop == settings.marginInches ? .accentColor : .secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func time(_ keyPath: ReferenceWritableKeyPath<Settings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = settings[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                settings[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    private func durationLabel(_ seconds: Double) -> String {
        switch seconds {
        case ..<60: "\(Int(seconds)) seconds"
        case 60: "1 minute"
        case ..<3600: "\(Int(seconds / 60)) minutes"
        default: "1 hour"
        }
    }

    private func inchLabel(_ inches: Double) -> String {
        let whole = Int(inches)
        let fraction = ["", "¼", "½", "¾"][Int(((inches - Double(whole)) * 4).rounded())]
        return whole == 0 ? fraction : "\(whole)\(fraction)"
    }
}

private struct AlbumList: View {
    @Bindable var settings: Settings
    @Environment(\.dismiss) private var dismiss
    @State private var albums: [Album]?

    var body: some View {
        List(albums ?? []) { album in
            Button {
                settings.albumID = album.id
                settings.albumTitle = album.title
                dismiss()
            } label: {
                HStack {
                    Text(album.title).foregroundStyle(.primary)
                    Spacer()
                    Text("\(album.count)").foregroundStyle(.secondary)
                    Image(systemName: "checkmark")
                        .opacity(album.id == settings.albumID ? 1 : 0)
                }
            }
        }
        .overlay {
            if albums == nil {
                ProgressView()
            } else if albums?.isEmpty == true {
                ContentUnavailableView("No albums", systemImage: "photo.on.rectangle", description: Text("Make an album in Photos, then come back."))
            }
        }
        .navigationTitle("Album")
        .task {
            albums = await Task.detached { PhotoLibrary.albums() }.value
        }
    }
}
