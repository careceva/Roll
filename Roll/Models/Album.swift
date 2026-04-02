import Foundation
import SwiftData

@Model
final class Album {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var sortOrder: Int
    var coverPhotoIdentifier: String?
    var photoLibraryIdentifier: String?

    @Relationship(deleteRule: .cascade, inverse: \MediaItem.album) var mediaItems: [MediaItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        sortOrder: Int = 0,
        coverPhotoIdentifier: String? = nil,
        photoLibraryIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.coverPhotoIdentifier = coverPhotoIdentifier
        self.photoLibraryIdentifier = photoLibraryIdentifier
    }
}
