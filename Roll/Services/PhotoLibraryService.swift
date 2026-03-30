import Photos
import UIKit

class PhotoLibraryService: NSObject {
    static let shared = PhotoLibraryService()

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

    func createAlbum(named albumName: String, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
        }) { success, _ in
            completion(success)
        }
    }

    func fetchPhotosForAlbum(named albumName: String) -> [PHAsset] {
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
        return result
    }

    func deleteAsset(_ asset: PHAsset, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }) { success, _ in
            completion(success)
        }
    }

    func getThumbnail(for asset: PHAsset, size: CGSize = CGSize(width: 200, height: 200), completion: @escaping (UIImage?) -> Void) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .fastFormat

        manager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }

    func getImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
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
            completion(image)
        }
    }

    func getAssetByLocalIdentifier(_ identifier: String) -> PHAsset? {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return results.firstObject
    }
}
