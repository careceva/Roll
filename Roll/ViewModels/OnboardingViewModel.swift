import Combine
import SwiftUI

class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var firstAlbumName: String = ""

    enum OnboardingStep {
        case welcome
        case permissions
        case createAlbum
        case complete
    }

    func moveToNext() {
        switch currentStep {
        case .welcome:
            currentStep = .permissions
        case .permissions:
            currentStep = .createAlbum
        case .createAlbum:
            currentStep = .complete
        case .complete:
            break
        }
    }

    func moveToPrevious() {
        switch currentStep {
        case .welcome:
            break
        case .permissions:
            currentStep = .welcome
        case .createAlbum:
            currentStep = .permissions
        case .complete:
            currentStep = .createAlbum
        }
    }

    func isCreateAlbumValid() -> Bool {
        !firstAlbumName.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
