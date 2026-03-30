import SwiftUI

struct Constants {
    struct Layout {
        static let cornerRadius: CGFloat = 12
        static let smallCornerRadius: CGFloat = 8
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 24

        static let shutterButtonSize: CGFloat = 70
        static let smallButtonSize: CGFloat = 50

        static let thumbnailSize: CGSize = CGSize(width: 150, height: 150)
        static let gridItemHeight: CGFloat = 150
    }

    struct Animation {
        static let defaultDuration: Double = 0.3
        static let slowDuration: Double = 0.5
        static let fastDuration: Double = 0.15
    }

    struct Colors {
        static let controlBackground = Color.black.opacity(0.4)
        static let controlText = Color.white
    }

    struct Camera {
        static let defaultZoomLevel: CGFloat = 1.0
        static let maxZoomLevel: CGFloat = 5.0
        static let minZoomLevel: CGFloat = 1.0
    }

    struct Images {
        static let albumIcon = "folder.fill"
        static let cameraIcon = "camera.fill"
        static let flashOn = "bolt.fill"
        static let flashOff = "bolt.slash.fill"
        static let flashAuto = "bolt.badge.automatic.fill"
        static let switchCamera = "arrow.triangle.2.circlepath"
        static let gallery = "photo.stack.fill"
        static let settings = "gear"
    }

    struct Text {
        static let appName = "Roll"
        static let tagline = "Organize before you shoot"
        static let permissionCamera = "Roll needs camera access to take photos and videos"
        static let permissionPhoto = "Roll saves your photos and videos to albums you create"
        static let permissionMicrophone = "Roll needs microphone access to record video with audio"
    }
}
