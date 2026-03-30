import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                CameraView()
                    .tag(0)

                GalleryView()
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
    }
}

#Preview {
    ContentView()
}
