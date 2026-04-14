import AVFoundation
import Combine
import SwiftData
import SwiftUI

class CameraViewModel: NSObject, ObservableObject {
    @Published var cameraService: CameraService
    @Published var lastCapturedImage: UIImage?
    @Published var showPhotoSaved = false
    @Published var lastPhotoLocalIdentifier: String?

    /// Tracks in-flight captures so rapid taps don't clobber each other's blink
    private var activeCaptures = 0

    override init() {
        self.cameraService = CameraService()
        super.init()
    }

    func capturePhoto(toAlbum album: Album, modelContext: ModelContext) {
        // INSTANT blink — fire immediately on tap, before capture even starts
        activeCaptures += 1
        withAnimation(.easeIn(duration: 0.04)) {
            showPhotoSaved = true
        }

        // Schedule blink-off (short delay for the blink to register visually)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.activeCaptures -= 1
            // Only dismiss blink if no other captures are in flight (rapid fire)
            if self.activeCaptures == 0 {
                withAnimation(.easeOut(duration: 0.08)) {
                    self.showPhotoSaved = false
                }
            }
        }

        // Fire capture — callback handles save, doesn't block next shot
        cameraService.capturePhoto { [weak self] (image: UIImage?) in
            guard let self = self, let image = image else { return }

            DispatchQueue.main.async {
                self.lastCapturedImage = image
            }

            // Photo library save runs fully in background
            PhotoLibraryService.shared.savePhotoToLibrary(image, toAlbum: album.name) { success, identifier in
                if success, let identifier = identifier {
                    PhotoLibraryService.shared.invalidateAlbumCache(for: album.name)

                    DispatchQueue.main.async {
                        let mediaItem = MediaItem(
                            localIdentifier: identifier,
                            mediaType: .photo
                        )
                        album.mediaItems.append(mediaItem)

                        do {
                            try modelContext.save()
                            self.lastPhotoLocalIdentifier = identifier
                        } catch {
                            print("Error saving media item: \(error)")
                        }
                    }
                }
            }
        }
    }

    func startVideoRecording(toAlbum album: Album, modelContext: ModelContext) {
        cameraService.startVideoRecording()
    }

    func stopVideoRecording(toAlbum album: Album, modelContext: ModelContext, completion: @escaping () -> Void) {
        // stopVideoRecording callback runs on sessionQueue
        cameraService.stopVideoRecording { [weak self] fileURL in
            guard let self = self, let url = fileURL else {
                completion()
                return
            }

            // Video saving and database operations can happen off main thread
            PhotoLibraryService.shared.saveVideoToLibrary(url, toAlbum: album.name) { success, identifier in
                try? FileManager.default.removeItem(at: url)

                if success, let identifier = identifier {
                    PhotoLibraryService.shared.invalidateAlbumCache(for: album.name)

                    DispatchQueue.main.async {
                        let mediaItem = MediaItem(
                            localIdentifier: identifier,
                            mediaType: .video,
                            duration: 0
                        )
                        album.mediaItems.append(mediaItem)

                        do {
                            try modelContext.save()
                        } catch {
                            print("Error saving media item: \(error)")
                        }

                        if let asset = PhotoLibraryService.shared.getAssetByLocalIdentifier(identifier) {
                            PhotoLibraryService.shared.getThumbnail(for: asset, size: CGSize(width: 200, height: 200)) { thumbnail in
                                DispatchQueue.main.async {
                                    self.lastCapturedImage = thumbnail
                                    self.lastPhotoLocalIdentifier = identifier
                                }
                            }
                        }
                    }
                }
                completion()
            }
        }
    }
}
