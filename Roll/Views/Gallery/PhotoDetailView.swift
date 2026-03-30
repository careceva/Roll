import SwiftUI
import Photos

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let assets: [PHAsset]
    let initialAsset: PHAsset
    @State private var currentIndex: Int
    @State private var image: UIImage?
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showEditor = false

    init(assets: [PHAsset], initialAsset: PHAsset) {
        self.assets = assets
        self.initialAsset = initialAsset
        let index = assets.firstIndex(where: { $0.localIdentifier == initialAsset.localIdentifier }) ?? 0
        _currentIndex = State(initialValue: index)
    }

    private var currentAsset: PHAsset? {
        guard currentIndex >= 0 && currentIndex < assets.count else { return nil }
        return assets[currentIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                    }
                    Spacer()

                    if assets.count > 1 {
                        Text("\(currentIndex + 1) / \(assets.count)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    // Edit button
                    if image != nil {
                        Button(action: { showEditor = true }) {
                            Text("Edit")
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(16)

                Spacer()

                // Photo
                if image != nil {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                            AsyncPhotoView(asset: asset)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                } else {
                    ProgressView()
                        .tint(.white)
                }

                Spacer()

                // Bottom bar
                HStack(spacing: 12) {
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(16)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { loadImage() }
        .onChange(of: currentIndex) { loadImage() }
        .sheet(isPresented: $showShareSheet) {
            if let image = image {
                ShareSheet(items: [image])
            }
        }
        .sheet(isPresented: $showEditor) {
            if let image = image {
                PhotoEditorView(image: image)
            }
        }
        .confirmationDialog("Delete Photo", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let asset = currentAsset {
                    PhotoLibraryService.shared.deleteAsset(asset) { _ in
                        DispatchQueue.main.async {
                            dismiss()
                        }
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this photo?")
        }
    }

    private func loadImage() {
        guard let asset = currentAsset else { return }
        PhotoLibraryService.shared.getImage(for: asset) { img in
            DispatchQueue.main.async {
                image = img
            }
        }
    }
}

struct AsyncPhotoView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .pinchToZoom()
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            PhotoLibraryService.shared.getImage(for: asset) { img in
                DispatchQueue.main.async { image = img }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PinchToZoom: ViewModifier {
    @State var scale: CGFloat = 1.0
    @State var lastScale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = lastScale * value
                    }
                    .onEnded { _ in
                        if scale < 1.0 {
                            withAnimation(.easeInOut(duration: 0.2)) { scale = 1.0 }
                        }
                        lastScale = scale
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if scale > 1.0 {
                        scale = 1.0
                        lastScale = 1.0
                    } else {
                        scale = 2.5
                        lastScale = 2.5
                    }
                }
            }
    }
}

extension View {
    func pinchToZoom() -> some View {
        modifier(PinchToZoom())
    }
}

#Preview {
    PhotoDetailView(assets: [], initialAsset: PHAsset())
}
