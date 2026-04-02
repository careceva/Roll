import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Camera", systemImage: "camera.fill") {
                CameraView()
            }

            Tab("Library", systemImage: "photo.stack") {
                GalleryView()
            }
        }
        // iOS 26: tint applies to the floating glass tab bar icons
        // No custom tint — let iOS 26 use the system accent colour for the floating glass tab bar
    }
}

#Preview {
    ContentView()
}
