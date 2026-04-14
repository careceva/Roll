import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    /// Set to `true` to freeze the preview with a snapshot overlay,
    /// set back to `false` to crossfade back to the live preview.
    var isFrozen: Bool = false

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if isFrozen {
            uiView.freezePreview()
        } else {
            uiView.unfreezePreview()
        }
    }
}

class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    /// Snapshot image view overlaid on top of the preview layer.
    private lazy var snapshotImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.isHidden = true
        addSubview(iv)
        return iv
    }()

    override func layoutSubviews() {
        super.layoutSubviews()
        snapshotImageView.frame = bounds
    }

    /// Captures the current preview layer contents and shows them as a static overlay.
    func freezePreview() {
        guard snapshotImageView.isHidden else { return }
        // Render the preview layer into an image
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let snapshot = renderer.image { ctx in
            previewLayer.render(in: ctx.cgContext)
        }
        snapshotImageView.image = snapshot
        snapshotImageView.alpha = 1
        snapshotImageView.isHidden = false
    }

    /// Crossfades from the snapshot overlay back to the live preview.
    func unfreezePreview() {
        guard !snapshotImageView.isHidden else { return }
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.snapshotImageView.alpha = 0
        } completion: { _ in
            self.snapshotImageView.isHidden = true
            self.snapshotImageView.image = nil
        }
    }
}

#Preview {
    Text("Camera Preview")
}
