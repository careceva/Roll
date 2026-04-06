import SwiftUI
import Photos
import AVKit
import CoreMedia

// MARK: - PhotoDetailView

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let assets: [PHAsset]
    let initialAsset: PHAsset
    var onBackToAlbum: (() -> Void)?
    @State private var currentIndex: Int
    @State private var image: UIImage?
    @State private var scrollID: Int?
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showEditor = false
    @State private var showChrome = true

    init(assets: [PHAsset], initialAsset: PHAsset, onBackToAlbum: (() -> Void)? = nil) {
        self.assets = assets
        self.initialAsset = initialAsset
        self.onBackToAlbum = onBackToAlbum
        let index = assets.firstIndex(where: {
            $0.localIdentifier == initialAsset.localIdentifier
        }) ?? 0
        _currentIndex = State(initialValue: index)
        _showChrome = State(initialValue: initialAsset.mediaType != .video)
    }

    private var currentAsset: PHAsset? {
        guard currentIndex >= 0 && currentIndex < assets.count else { return nil }
        return assets[currentIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // ── Media pager ────────────────────────────────────────────────
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(assets.enumerated()), id: \.offset) { index, asset in
                            mediaCell(asset: asset, index: index, size: geo.size)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
.scrollPosition(id: $scrollID)
                .ignoresSafeArea()
            }
            .ignoresSafeArea()

            // ── Chrome — photos only ───────────────────────────────────────
            if showChrome && currentAsset?.mediaType != .video {
                VStack {
                    HStack {
                        Button(action: {
                            if let onBackToAlbum {
                                onBackToAlbum()
                            } else {
                                dismiss()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                        }
                        .glassEffect(in: Circle())

                        Spacer()

                        if assets.count > 1 {
                            Text("\(currentIndex + 1) / \(assets.count)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .glassEffect(in: Capsule())
                        }

                        Spacer()

                        if image != nil {
                            Button(action: { showEditor = true }) {
                                Text("Edit")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                            }
                            .glassEffect(in: Capsule())
                        } else {
                            Color.clear.frame(width: 60, height: 36)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 17)

                    Spacer()

                    HStack(spacing: 40) {
                        Button(action: { showShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                        }
                        .glassEffect(in: Circle())

                        Button(action: { showDeleteConfirmation = true }) {
                            Image(systemName: "trash")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.red)
                                .frame(width: 48, height: 48)
                        }
                        .glassEffect(in: Circle())
                    }
                    .padding(.bottom, 48)
                }
                .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            scrollID = currentIndex
            loadMedia()
        }
        .onChange(of: scrollID) { _, new in
            guard let idx = new, idx != currentIndex else { return }
            currentIndex = idx
        }
        .onChange(of: currentIndex) {
            loadMedia()
            showChrome = currentAsset?.mediaType != .video
            if scrollID != currentIndex { scrollID = currentIndex }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = image { ShareSheet(items: [image]) }
        }
        .sheet(isPresented: $showEditor) {
            if let image = image { PhotoEditorView(image: image) }
        }
        .confirmationDialog(
            currentAsset?.mediaType == .video ? "Delete Video" : "Delete Photo",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                if let asset = currentAsset {
                    PhotoLibraryService.shared.deleteAsset(asset) { _ in
                        DispatchQueue.main.async { dismiss() }
                    }
                }
            }
        } message: {
            Text(currentAsset?.mediaType == .video
                 ? "Are you sure you want to delete this video?"
                 : "Are you sure you want to delete this photo?")
        }
    }

    private func loadMedia() {
        guard let asset = currentAsset, asset.mediaType != .video else { return }
        PhotoLibraryService.shared.getImage(for: asset) { img in
            DispatchQueue.main.async { image = img }
        }
    }

    @ViewBuilder
    private func mediaCell(asset: PHAsset, index: Int, size: CGSize) -> some View {
        if asset.mediaType == .video {
            VideoAssetView(asset: asset, onDelete: {
                showDeleteConfirmation = true
            }, onDismiss: {
                dismiss()
            })
            .frame(width: size.width, height: size.height)
        } else {
            AsyncPhotoView(asset: asset)
                .frame(width: size.width, height: size.height)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { showChrome.toggle() }
                }
        }
    }


}

// MARK: - VideoAssetView

struct VideoAssetView: View {
    let asset: PHAsset
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    @State private var isMuted = false
    @State private var isDragging = false
    @State private var timeObserver: Any?
    @State private var showShareSheet = false
    @State private var videoShareURL: URL?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }

            // Back button — top left
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                    }
                    .glassEffect(in: Circle())
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 17)
                Spacer()
            }

            // Bottom: share + delete circles + controls pill
            VStack(spacing: 0) {
                Spacer()

                HStack(spacing: 40) {
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                    }
                    .glassEffect(in: Circle())

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.red)
                            .frame(width: 48, height: 48)
                    }
                    .glassEffect(in: Circle())
                }
                .padding(.bottom, 16)

                if player != nil {
                    videoControlsPill
                        .padding(.horizontal, 20)
                        .padding(.bottom, 48)
                }
            }
        }
        .onAppear { loadPlayer() }
        .onDisappear { cleanup() }
        .sheet(isPresented: $showShareSheet) {
            if let url = videoShareURL { ShareSheet(items: [url]) }
        }
    }

    // MARK: Controls Pill

    private var videoControlsPill: some View {
        HStack(spacing: 12) {
            // Play / Pause
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 24, height: 24)
            }

            // Progress slider
            Slider(
                value: $currentTime,
                in: 0...max(duration, 0.01),
                onEditingChanged: { editing in
                    isDragging = editing
                    if editing {
                        player?.pause()
                    } else {
                        let target = CMTime(seconds: currentTime, preferredTimescale: 600)
                        player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
                        if isPlaying { player?.play() }
                    }
                }
            )
            .tint(.primary)

            // Remaining time
            Text("-\(formatTime(max(0, duration - currentTime)))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(minWidth: 36)

            // Mute toggle
            Button(action: {
                isMuted.toggle()
                player?.isMuted = isMuted
            }) {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 22, height: 22)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .glassEffect(in: Capsule())
    }

    // MARK: Helpers

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            // If at end, restart
            if currentTime >= duration - 0.1 {
                player.seek(to: .zero)
            }
            player.play()
        }
        isPlaying.toggle()
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func loadPlayer() {
        guard player == nil else { return }
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            guard let avAsset else { return }
            let shareURL = (avAsset as? AVURLAsset)?.url
            DispatchQueue.main.async {
                videoShareURL = shareURL
                let item = AVPlayerItem(asset: avAsset)
                let p = AVPlayer(playerItem: item)
                p.isMuted = isMuted
                player = p

                // Duration
                Task {
                    let d = try? await avAsset.load(.duration)
                    let secs = d?.seconds ?? 1
                    await MainActor.run {
                        duration = secs.isFinite && secs > 0 ? secs : 1
                    }
                }

                // Periodic time observer (~30fps)
                let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
                timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                    guard !isDragging else { return }
                    currentTime = time.seconds.isFinite ? time.seconds : 0
                }

                // Auto-play
                p.play()
                isPlaying = true

                // Loop on end
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item,
                    queue: .main
                ) { _ in
                    p.seek(to: .zero)
                    p.play()
                    isPlaying = true
                    currentTime = 0
                }
            }
        }
    }

    private func cleanup() {
        player?.pause()
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
        NotificationCenter.default.removeObserver(self)
        player = nil
    }
}

// MARK: - VideoPlayerLayer (bare AVPlayerLayer, no native controls)

struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> _PlayerView {
        let v = _PlayerView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspect
        v.backgroundColor = .black
        return v
    }

    func updateUIView(_ uiView: _PlayerView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class _PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

// MARK: - AsyncPhotoView

struct AsyncPhotoView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .drawingGroup()
                    .pinchToZoom()
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear { loadImage() }
    }

    @MainActor
    private func loadImage() {
        PhotoLibraryService.shared.getImage(for: asset) { img in
            DispatchQueue.main.async { self.image = img }
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - PinchToZoom

struct PinchToZoom: ViewModifier {
    @State var scale: CGFloat = 1.0
    @State var lastScale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in scale = lastScale * value }
                    .onEnded { _ in
                        if scale < 1.0 {
                            withAnimation(.spring(duration: 0.35)) { scale = 1.0 }
                        }
                        lastScale = scale
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(duration: 0.35)) {
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
