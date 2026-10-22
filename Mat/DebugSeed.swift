#if DEBUG
import Photos
import UIKit

/// Simulator testing only: launched with `-MatSeedAlbum YES`, puts every photo in the library into
/// a "Mat Test" album and selects it, since simctl can add photos but not make albums.
enum DebugSeed {
    static func runIfRequested(_ settings: Settings) async {
        guard UserDefaults.standard.bool(forKey: "MatSeedAlbum") else { return }
        let title = "Mat Test"
        let existing = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        var album: PHAssetCollection?
        existing.enumerateObjects { c, _, stop in
            if c.localizedTitle == title { album = c; stop.pointee = true }
        }
        if album == nil {
            var placeholder: String?
            try? await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
                request.addAssets(PHAsset.fetchAssets(with: .image, options: nil))
                placeholder = request.placeholderForCreatedAssetCollection.localIdentifier
            }
            if let placeholder {
                album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder], options: nil).firstObject
            }
        }
        guard let album else { return }
        settings.albumTitle = title
        settings.albumID = album.localIdentifier
    }

    /// `-MatRotateAfter <seconds>` turns the interface to landscape mid-slideshow, which the
    /// Xcode 27 simulator panel can't do by itself.
    @MainActor
    static func rotateIfRequested() async {
        let delay = UserDefaults.standard.double(forKey: "MatRotateAfter")
        guard delay > 0 else { return }
        try? await Task.sleep(for: .seconds(delay))
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeLeft))
    }
}
#endif
