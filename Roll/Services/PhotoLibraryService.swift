import Photos
import UIKit

extension Notification.Name {
    static let photoLibraryDidChange = Notification.Name("photoLibraryDidChange")
}

class PhotoLibraryService: NSObject {
    static let shared = PhotoLibraryService()

    // Thumbnail cache keyed by "localIdentifier-WIDTHxHEIGHT"
    private let thumbnailCache = NSCache<NSString, UIImage>()

    // Full-resolution image cache (limited to 5-10 images)
    private let imageCache = NSCache<NSString, UIImage>()

    // Album fetch results cache keyed by album name
    private let albumPhotoCache = NSCache<NSString, NSArray>()

    // Track in-flight thumbnail requests to enable cancellation
    private var inFlightThumbnailRequests: [String: PHImageRequestID] = [:]
    private let requestLock = NSLock()

    override init() {
        super.init()
        // Limit full-resolution image cache to ~5-10 images
        imageCache.totalCostLimit = 100 * 1024 * 1024 // 100MB max
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: - iOS Photo Library Album Queries

    /// Fetches all user-created albums from the iOS Photos library as [localIdentifier: title]
    func fetchiOSAlbums() -> [String: String] {
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: nil
        )
        var albums = [String: String]()
        collections.enumerateObjects { collection, _, _ in
            if let title = collection.localizedTitle {
                albums[collection.localIdentifier] = title
            }
        }
        return albums
    }

    func savePhotoToLibrary(_ image: UIImage, toAlbum albumName: String, completion: @escaping (Bool, String?) -> Void) {
        var placeholderIdentifier: String?

        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            placeholderIdentifier = creationRequest.placeholderForCreatedAsset?.localIdentifier
        }) { success, error in
            if success, let identifier = placeholderIdentifier {
                self.addAssetToAlbum(identifier: identifier, albumName: albumName) { addSuccess in
                    completion(addSuccess, identifier)
                }
            } else {
                completion(false, nil)
            }
        }
    }

    func saveVideoToLibrary(_ videoURL: URL, toAlbum albumName: String, completion: @escaping (Bool, String?) -> Void) {
        var placeholderIdentifier: String?

        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)!
            placeholderIdentifier = creationRequest.placeholderForCreatedAsset?.localIdentifier
        }) { success, error in
            if success, let identifier = placeholderIdentifier {
                self.addAssetToAlbum(identifier: identifier, albumName: albumName) { addSuccess in
                    completion(addSuccess, identifier)
                }
            } else {
                completion(false, nil)
            }
        }
    }

    private func addAssetToAlbum(identifier: String, albumName: String, completion: @escaping (Bool) -> Void) {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            completion(false)
            return
        }

        var albumCollection: PHAssetCollection?
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if collections.count > 0 {
            albumCollection = collections.firstObject
        }

        if let collection = albumCollection {
            PHPhotoLibrary.shared().performChanges({
                guard let collectionEditRequest = PHAssetCollectionChangeRequest(for: collection) else { return }
                collectionEditRequest.addAssets([asset] as NSArray)
            }) { success, _ in
                completion(success)
            }
        } else {
            PHPhotoLibrary.shared().performChanges({
                let albumCreationRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                albumCreationRequest.addAssets([asset] as NSArray)
            }) { success, _ in
                completion(success)
            }
        }
    }

    func createAlbum(named albumName: String, completion: @escaping (Bool, String?) -> Void) {
        var placeholderIdentifier: String?

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            placeholderIdentifier = request.placeholderForCreatedAssetCollection.localIdentifier
        }) { success, _ in
            completion(success, placeholderIdentifier)
        }
    }

    func fetchPhotosForAlbum(named albumName: String) -> [PHAsset] {
        // Check cache first
        let cacheKey = albumName as NSString
        if let cachedResults = albumPhotoCache.object(forKey: cacheKey) as? [PHAsset] {
            return cachedResults
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        guard let collection = collections.firstObject else { return [] }

        let assetFetchOptions = PHFetchOptions()
        assetFetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(in: collection, options: assetFetchOptions)

        var result: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            result.append(asset)
        }

        // Cache the result
        albumPhotoCache.setObject(result as NSArray, forKey: cacheKey)
        return result
    }

    // MARK: - Cache Invalidation

    /// Remove cached album fetch results so next fetch gets fresh data from Photos library.
    func invalidateAlbumCache(for albumName: String) {
        albumPhotoCache.removeObject(forKey: albumName as NSString)
    }

    /// Remove all cached album fetch results.
    func invalidateAllAlbumCaches() {
        albumPhotoCache.removeAllObjects()
    }

    // MARK: - Deletion

    func deleteAsset(_ asset: PHAsset, fromAlbumNamed albumName: String? = nil, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }) { success, _ in
            if success, let albumName = albumName {
                self.invalidateAlbumCache(for: albumName)
            }
            completion(success)
        }
    }

    func deleteAlbum(named albumName: String, completion: @escaping (Bool) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        guard let collection = collections.firstObject else {
            completion(false)
            return
        }

        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.deleteAssetCollections([collection] as NSArray)
        }) { success, _ in
            if success {
                self.invalidateAlbumCache(for: albumName)
            }
            completion(success)
        }
    }

    func getThumbnail(for asset: PHAsset, size: CGSize = CGSize(width: 200, height: 200), completion: @escaping (UIImage?) -> Void) {
        // Create cache key
        let cacheKey = "\(asset.localIdentifier)-\(Int(size.width))x\(Int(size.height))" as NSString

        // Check cache first
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            DispatchQueue.main.async {
                completion(cached)
            }
            return
        }

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        let requestID = manager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            if let image = image {
                // Cache the result
                self.thumbnailCache.setObject(image, forKey: cacheKey)
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }

            // Clean up tracking
            self.requestLock.lock()
            self.inFlightThumbnailRequests.removeValue(forKey: cacheKey as String)
            self.requestLock.unlock()
        }

        // Track the request for potential cancellation
        requestLock.lock()
        inFlightThumbnailRequests[cacheKey as String] = requestID
        requestLock.unlock()
    }

    /// Cancel in-flight thumbnail request for a given asset
    func cancelThumbnailRequest(for asset: PHAsset, size: CGSize = CGSize(width: 200, height: 200)) {
        let cacheKey = "\(asset.localIdentifier)-\(Int(size.width))x\(Int(size.height))" as NSString
        requestLock.lock()
        if let requestID = inFlightThumbnailRequests[cacheKey as String] {
            PHImageManager.default().cancelImageRequest(requestID)
            inFlightThumbnailRequests.removeValue(forKey: cacheKey as String)
        }
        requestLock.unlock()
    }

    func getImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        // Create cache key for full-resolution image
        let cacheKey = "\(asset.localIdentifier)-full" as NSString

        // Check cache first
        if let cached = imageCache.object(forKey: cacheKey) {
            DispatchQueue.main.async {
                completion(cached)
            }
            return
        }

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        manager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                // Cache with cost estimate
                self.imageCache.setObject(image, forKey: cacheKey, cost: Int(image.size.width * image.size.height))
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    func getAssetByLocalIdentifier(_ identifier: String) -> PHAsset? {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return results.firstObject
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension PhotoLibraryService: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .photoLibraryDidChange, object: nil)
        }
    }
}
