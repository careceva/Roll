import WidgetKit
import SwiftUI

@available(iOS 18.0, *)
struct RollCameraToggle: ControlWidget {
    static let kind: String = "com.roll.camera.control"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LaunchCameraIntent()) {
                Label("Roll Camera", systemImage: "camera.fill")
            }
        }
        .displayName("Roll Camera")
        .description("Quick launch Roll camera")
    }
}
