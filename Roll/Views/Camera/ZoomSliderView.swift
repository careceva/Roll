import SwiftUI

struct ZoomSliderView: View {
    @ObservedObject var cameraService: CameraService

    var body: some View {
        // Zoom is now handled via pinch gesture and shown as text indicator
        // This view is kept as a no-op to avoid breaking references
        EmptyView()
    }
}

#Preview {
    ZoomSliderView(cameraService: CameraService())
}
