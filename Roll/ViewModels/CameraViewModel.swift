import AVFoundation
import Combine
import SwiftData
import SwiftUI

class CameraViewModel: NSObject, ObservableObject {
    @Published var cameraService: CameraService
    @Published var lastCapturedImage: UIImage?
    @Published var showPhotoSaved = false
    @Published var lastPhotoLocalIdentifier: String?

    override init() {
        self.cameraService = CameraService()
        super.init()
    }

    func capturePhoto(toAlbum album: Album, modelContext: ModelContext) {
        cameraService.capturePhoto { [weak self] (image: UIImage?) in
            guard let self = self, let image = image else { return }

            self.lastCapturedImage = image
            self.showPhotoSaved = true

            PhotoLibraryService.shared.savePhotoToLibrary(image, toAlbum: album.name) { success, identifier in
                if success, let identifier = identifier {
                    let mediaItem = MediaItem(
                        localIdentifier: identifier,
                        mediaType: .photo
                    )
                    album.mediaItems.append(mediaItem)
                    modelContext.insert(mediaItem)

                    do {
                        try modelContext.save()
                        DispatchQueue.main.async {
                            self.lastPhotoLocalIdentifier = identifier
                        }
                    } catch {
                        print("Error saving media item: \(error)")
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showPhotoSaved = false
            }
        }
    }

    func startVideoRecording(toAlbum album: Album, modelContext: ModelContext) {
        cameraService.startVideoRecording()
    }

    func stopVideoRecording(toAlbum album: Album, modelContext: ModelContext, completion: @escaping () -> Void) {
        cameraService.stopVideoRecording { [weak self] fileURL in
            guard let self = self, let url = fileURL else {
                completion()
                return
            }

            PhotoLibraryService.shared.saveVideoToLibrary(url, toAlbum: album.name) { success, identifier in
                if success, let identifier = identifier {
                    let mediaItem = MediaItem(
                        localIdentifier: identifier,
                        mediaType: .video,
                        duration: 0
                    )
                    album.mediaItems.append(mediaItem)
                    modelContext.insert(mediaItem)

                    do {
                        try modelContext.save()
                        DispatchQueue.main.async {
                            self.lastPhotoLocalIdentifier = identifier
                        }
                    } catch {
                        print("Error saving media item: \(error)")
                    }
                }
                completion()
            }

            try? FileManager.default.removeItem(at: url)
        }
    }
}
