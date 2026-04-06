import AppIntents

@available(iOS 18.0, *)
struct LaunchCameraIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Roll Camera"
    static var description: IntentDescription = "Opens the Roll camera app"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
