import SwiftUI
import SwiftData

@main
struct RollApp: App {
    @AppStorage("onboardingComplete") var onboardingComplete = false
    @StateObject private var permissionService = PermissionService()

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
            if onboardingComplete {
                ContentView()
                    .environmentObject(permissionService)
                    .modelContainer(modelContainer)
            } else {
                OnboardingFlow(onboardingComplete: $onboardingComplete)
                    .environmentObject(permissionService)
                    .modelContainer(modelContainer)
            }
        }
    }
}
