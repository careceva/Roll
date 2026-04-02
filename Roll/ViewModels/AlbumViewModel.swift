import Combine
import SwiftData
import Foundation

class AlbumViewModel: ObservableObject {
    @Published var albums: [Album] = []
    @Published var selectedAlbum: Album?
    @Published var isCreatingAlbum = false

    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchAlbums()
        observePhotoLibraryChanges()
    }

    // MARK: - Photo Library Change Observation

    private func observePhotoLibraryChanges() {
        NotificationCenter.default.publisher(for: .photoLibraryDidChange)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reconcileWithPhotoLibrary()
            }
            .store(in: &cancellables)
    }

    /// Syncs local SwiftData albums with iOS Photos library.
    /// Removes albums that no longer exist in iOS and updates renamed albums.
    func reconcileWithPhotoLibrary() {
        let iOSAlbums = PhotoLibraryService.shared.fetchiOSAlbums()

        var didChange = false
        for album in albums {
            guard let libraryID = album.photoLibraryIdentifier else { continue }

            if let currentTitle = iOSAlbums[libraryID] {
                // Album still exists — update name if it was renamed
                if album.name != currentTitle {
                    album.name = currentTitle
                    didChange = true
                }
            } else {
                // Album was deleted from iOS Photos
                modelContext.delete(album)
                didChange = true
            }
        }

        if didChange {
            do {
                try modelContext.save()
            } catch {
                print("Error saving after reconciliation: \(error)")
            }
            fetchAlbums()

            // If the selected album was deleted, pick the first available
            if let selected = selectedAlbum, !albums.contains(where: { $0.id == selected.id }) {
                selectedAlbum = albums.first
            }
        }
    }

    func fetchAlbums() {
        // Fetch operations are lightweight and synchronous, safe on main thread
        let descriptor = FetchDescriptor<Album>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        do {
            let fetchedAlbums = try modelContext.fetch(descriptor)
            // Batch UI updates
            DispatchQueue.main.async {
                self.albums = fetchedAlbums
                // If the selected album was deleted, fall back to first available
                if let selected = self.selectedAlbum,
                   !fetchedAlbums.contains(where: { $0.id == selected.id }) {
                    self.selectedAlbum = fetchedAlbums.first
                } else if self.selectedAlbum == nil && !fetchedAlbums.isEmpty {
                    self.selectedAlbum = fetchedAlbums[0]
                }
            }
        } catch {
            print("Error fetching albums: \(error)")
        }
    }

    func createAlbum(name: String) {
        let newAlbum = Album(name: name, sortOrder: albums.count)
        modelContext.insert(newAlbum)

        do {
            try modelContext.save()
            fetchAlbums()
            selectedAlbum = newAlbum
        } catch {
            print("Error creating album: \(error)")
        }

        PhotoLibraryService.shared.createAlbum(named: name) { [weak self] _, identifier in
            DispatchQueue.main.async {
                newAlbum.photoLibraryIdentifier = identifier
                try? self?.modelContext.save()
            }
        }
    }

    func deleteAlbum(_ album: Album) {
        modelContext.delete(album)
        do {
            try modelContext.save()
            fetchAlbums()
        } catch {
            print("Error deleting album: \(error)")
        }
    }

    func cycleToNextAlbum() {
        guard !albums.isEmpty else { return }

        if let currentIndex = albums.firstIndex(where: { $0.id == selectedAlbum?.id }) {
            let nextIndex = (currentIndex + 1) % albums.count
            let newAlbum = albums[nextIndex]
            // Only update if actually changing to prevent unnecessary redraws
            if newAlbum.id != selectedAlbum?.id {
                selectedAlbum = newAlbum
            }
        } else if selectedAlbum == nil {
            selectedAlbum = albums[0]
        }
    }

    func cycleToPreviousAlbum() {
        guard !albums.isEmpty else { return }

        if let currentIndex = albums.firstIndex(where: { $0.id == selectedAlbum?.id }) {
            let nextIndex = currentIndex == 0 ? albums.count - 1 : currentIndex - 1
            let newAlbum = albums[nextIndex]
            // Only update if actually changing to prevent unnecessary redraws
            if newAlbum.id != selectedAlbum?.id {
                selectedAlbum = newAlbum
            }
        } else if selectedAlbum == nil {
            selectedAlbum = albums[0]
        }
    }
}
