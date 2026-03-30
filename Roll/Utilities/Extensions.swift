import SwiftUI

extension Color {
    static let cameraBackground = Color(UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0))
}

extension Date {
    func formattedAsTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    func formattedAsDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }

    func formattedAsDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    func isToday() -> Bool {
        return Calendar.current.isDateInToday(self)
    }

    func isYesterday() -> Bool {
        return Calendar.current.isDateInYesterday(self)
    }

    func isThisYear() -> Bool {
        return Calendar.current.component(.year, from: self) == Calendar.current.component(.year, from: Date())
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func withRoundedCorners(radius: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()
            self.draw(in: rect)
        }
    }
}

extension CGSize {
    func aspectFilled(into container: CGSize) -> CGSize {
        let aspectRatio = self.width / self.height
        let containerAspectRatio = container.width / container.height

        if aspectRatio > containerAspectRatio {
            let height = container.height
            let width = height * aspectRatio
            return CGSize(width: width, height: height)
        } else {
            let width = container.width
            let height = width / aspectRatio
            return CGSize(width: width, height: height)
        }
    }
}

extension String {
    func isValidAlbumName() -> Bool {
        let trimmed = trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.count <= 100
    }
}
