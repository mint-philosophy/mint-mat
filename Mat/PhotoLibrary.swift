import Photos
import UIKit

struct Album: Identifiable, Hashable {
    let id: String
    let title: String
    let count: Int
}

struct PhotoRef {
    let id: String
    /// Width over height, as the photo is displayed.
    let aspect: Double
}

enum PhotoLibrary {
    private static var imagesOnly: PHFetchOptions {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        return options
    }

    /// Favourites first, then every album (including shared ones) that holds at least one photo.
    static func albums() -> [Album] {
        func collect(_ collections: PHFetchResult<PHAssetCollection>) -> [Album] {
            (0..<collections.count).compactMap { i in
                let collection = collections.object(at: i)
                let count = PHAsset.fetchAssets(in: collection, options: imagesOnly).count
                guard count > 0 else { return nil }
                return Album(id: collection.localIdentifier, title: collection.localizedTitle ?? "Untitled", count: count)
            }
        }
        let favourites = collect(PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil))
        let others = collect(PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil))
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return favourites + others
    }

    static func photos(inAlbum id: String) -> [PhotoRef] {
        guard let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject else { return [] }
        var refs: [PhotoRef] = []
        PHAsset.fetchAssets(in: collection, options: imagesOnly).enumerateObjects { asset, _, _ in
            guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { return }
            refs.append(PhotoRef(id: asset.localIdentifier, aspect: Double(asset.pixelWidth) / Double(asset.pixelHeight)))
        }
        return refs
    }

    /// Loads a photo at least `pixels` in each direction, downloading the original from iCloud if needed.
    static func image(id: String, pixels: CGSize) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat // the handler runs exactly once
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: pixels, contentMode: .aspectFill, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

/// Reports any change to the library, so the album can be re-read before the next photo.
final class LibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
    private let onChange: @MainActor @Sendable () -> Void

    init(onChange: @escaping @MainActor @Sendable () -> Void) {
        self.onChange = onChange
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async(execute: onChange)
    }
}
