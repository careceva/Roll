import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var onboardingComplete: Bool
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            Group {
                switch viewModel.currentStep {
                case .welcome:
                    WelcomeView(onContinue: {
                        withAnimation(.easeInOut) {
                            viewModel.moveToNext()
                        }
                    })

                case .permissions:
                    PermissionView(onContinue: {
                        withAnimation(.easeInOut) {
                            viewModel.moveToNext()
                        }
                    })

                case .createAlbum:
                    CreateFirstAlbumView(onComplete: {
                        withAnimation(.easeInOut) {
                            viewModel.moveToNext()
                        }
                    })

                case .complete:
                    Color.clear
                        .onAppear {
                            onboardingComplete = true
                        }
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}

#Preview {
    OnboardingFlow(onboardingComplete: .constant(false))
}
