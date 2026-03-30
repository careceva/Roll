import Foundation
import SwiftData

enum MediaType: String, Codable {
    case photo
    case video
}

@Model
final class MediaItem {
    @Attribute(.unique) var id: UUID
    var localIdentifier: String
    var capturedAt: Date
    var mediaType: MediaType
    var duration: TimeInterval = 0

    var album: Album?

    init(
        id: UUID = UUID(),
        localIdentifier: String,
        capturedAt: Date = Date(),
        mediaType: MediaType = .photo,
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.localIdentifier = localIdentifier
        self.capturedAt = capturedAt
        self.mediaType = mediaType
        self.duration = duration
    }
}
