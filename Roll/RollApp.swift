import SwiftUI
import SwiftData

@main
struct RollApp: App {
    @AppStorage("onboardingComplete") var onboardingComplete = false
    @StateObject private var permissionService = PermissionService()
    @State private var recoverableAlbums: [String] = []
    @State private var showRestorePrompt = false

    let modelContainer: ModelContainer

    init() {
        let schema = Schema([Album.self, MediaItem.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showRestorePrompt {
                    RestoreAlbumsView(
                        albumNames: recoverableAlbums,
                        onRestore: {
                            restoreAlbums(recoverableAlbums)
                            showRestorePrompt = false
                            onboardingComplete = true
                        },
                        onFreshStart: {
                            iCloudBackupService.shared.clear()
                            showRestorePrompt = false
                            // Keep onboardingComplete = false so normal onboarding runs
                        }
                    )
                } else if onboardingComplete {
                    ContentView()
                        .environmentObject(permissionService)
                        .modelContainer(modelContainer)
                        .onAppear {
                            _ = PhotoLibraryService.shared
                        }
                } else {
                    OnboardingFlow(onboardingComplete: $onboardingComplete)
                        .environmentObject(permissionService)
                        .modelContainer(modelContainer)
                }
            }
            .modelContainer(modelContainer)
            .task {
                checkForRestore()
            }
        }
    }

    // MARK: - Restore Logic

    private func checkForRestore() {
        guard !onboardingComplete, !showRestorePrompt else { return }
        let recoverable = iCloudBackupService.shared.recoverableAlbumNames()
        guard !recoverable.isEmpty else { return }
        recoverableAlbums = recoverable
        showRestorePrompt = true
    }

    private func restoreAlbums(_ names: [String]) {
        let context = modelContainer.mainContext
        let existing = (try? context.fetch(FetchDescriptor<Album>())) ?? []
        let existingNames = Set(existing.map(\.name))

        for (index, name) in names.enumerated() where !existingNames.contains(name) {
            let album = Album(name: name, sortOrder: index)
            context.insert(album)
        }
        try? context.save()
        iCloudBackupService.shared.saveAlbums(names)
    }
}
