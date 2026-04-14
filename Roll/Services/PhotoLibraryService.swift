import Photos
import UIKit

extension Notification.Name {
    static let photoLibraryDidChange = Notification.Name("photoLibraryDidChange")
}

class PhotoLibraryService: NSObject {
    static let shared = PhotoLibraryService()

    // PHCachingImageManager for pre-heating nearby assets
    let cachingManager = PHCachingImageManager()

    // Thumbnail cache keyed by "localIdentifier-WIDTHxHEIGHT"
    private let thumbnailCache = NSCache<NSString, UIImage>()

    // Full-resolution image cache (limited to 5-10 images)
    private let imageCache = NSCache<NSString, UIImage>()

    // Album fetch results cache keyed by album name
    private let albumPhotoCache = NSCache<NSString, NSArray>()

    // Track in-flight thumbnail requests to enable cancellation
    private var inFlightThumbnailRequests: [String: PHImageRequestID] = [:]
    private let requestLock = NSLock()

    /// Screen-scale-aware thumbnail size for grid cells.
    static let scaledThumbnailSize: CGSize = {
        let scale: CGFloat = 3.0 // retina scale; avoids deprecated UIScreen.main on iOS 26
        let cellPt: CGFloat = 130 // approximate cell width in points (screen / 3 cols)
        let px = cellPt * scale
        return CGSize(width: px, height: px)
    }()

    override init() {
        super.init()
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
            guard let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL) else { return }
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

    func renameAlbum(from oldName: String, to newName: String, completion: @escaping (Bool) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", oldName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        guard let collection = collections.firstObject else {
            completion(false)
            return
        }

        PHPhotoLibrary.shared().performChanges({
            guard let request = PHAssetCollectionChangeRequest(for: collection) else { return }
            request.title = newName
        }) { success, _ in
            if success {
                self.invalidateAlbumCache(for: oldName)
            }
            completion(success)
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

    // MARK: - Pre-heating (PHCachingImageManager)

    /// Start pre-fetching thumbnails for assets about to scroll into view.
    func startCaching(assets: [PHAsset], targetSize: CGSize? = nil) {
        let size = targetSize ?? Self.scaledThumbnailSize
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isSynchronous = false
        cachingManager.startCachingImages(for: assets, targetSize: size, contentMode: .aspectFill, options: options)
    }

    /// Stop pre-fetching for assets that scrolled out of the preheat window.
    func stopCaching(assets: [PHAsset], targetSize: CGSize? = nil) {
        let size = targetSize ?? Self.scaledThumbnailSize
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isSynchronous = false
        cachingManager.stopCachingImages(for: assets, targetSize: size, contentMode: .aspectFill, options: options)
    }

    /// Pre-fetch full-resolution images for nearby assets in the detail pager.
    func startCachingFullRes(assets: [PHAsset]) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        cachingManager.startCachingImages(for: assets, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options)
    }

    /// Stop pre-fetching full-resolution images.
    func stopCachingFullRes(assets: [PHAsset]) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        cachingManager.stopCachingImages(for: assets, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options)
    }

    /// Reset all cached images (e.g. when the album changes).
    func resetCaching() {
        cachingManager.stopCachingImagesForAllAssets()
    }

    // MARK: - Thumbnail Loading (opportunistic, progressive)

    /// Request a thumbnail. The completion may be called **twice** — first with a fast low-res
    /// decode, then with the higher-quality result. The `isDegraded` flag distinguishes the two.
    func getThumbnail(
        for asset: PHAsset,
        size: CGSize? = nil,
        completion: @escaping (_ image: UIImage?, _ isDegraded: Bool) -> Void
    ) {
        let targetSize = size ?? Self.scaledThumbnailSize
        let cacheKey = "\(asset.localIdentifier)-\(Int(targetSize.width))x\(Int(targetSize.height))" as NSString

        // Check in-memory cache — already high quality
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            DispatchQueue.main.async { completion(cached, false) }
            return
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic   // low-res immediately, high-res later
        options.resizeMode = .fast
        options.isSynchronous = false

        let requestID = cachingManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, info in
            guard let self, let image else {
                DispatchQueue.main.async { completion(nil, false) }
                return
            }

            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false

            // Only cache the final (non-degraded) result
            if !degraded {
                self.thumbnailCache.setObject(image, forKey: cacheKey)
            }

            DispatchQueue.main.async { completion(image, degraded) }

            if !degraded {
                self.requestLock.lock()
                self.inFlightThumbnailRequests.removeValue(forKey: cacheKey as String)
                self.requestLock.unlock()
            }
        }

        requestLock.lock()
        inFlightThumbnailRequests[cacheKey as String] = requestID
        requestLock.unlock()
    }

    /// Cancel in-flight thumbnail request for a given asset
    func cancelThumbnailRequest(for asset: PHAsset, size: CGSize? = nil) {
        let targetSize = size ?? Self.scaledThumbnailSize
        let cacheKey = "\(asset.localIdentifier)-\(Int(targetSize.width))x\(Int(targetSize.height))" as NSString
        requestLock.lock()
        if let requestID = inFlightThumbnailRequests[cacheKey as String] {
            cachingManager.cancelImageRequest(requestID)
            inFlightThumbnailRequests.removeValue(forKey: cacheKey as String)
        }
        requestLock.unlock()
    }

    // MARK: - Full-Resolution Loading

    func getImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = "\(asset.localIdentifier)-full" as NSString

        if let cached = imageCache.object(forKey: cacheKey) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        cachingManager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            if let image {
                self?.imageCache.setObject(image, forKey: cacheKey, cost: Int(image.size.width * image.size.height))
                DispatchQueue.main.async { completion(image) }
            } else {
                DispatchQueue.main.async { completion(nil) }
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
