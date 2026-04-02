import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var onboardingComplete: Bool
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            // ── Permanent dark base — prevents any white flash during transitions ──
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.04, green: 0.04, blue: 0.14), location: 0),
                    .init(color: Color(red: 0.07, green: 0.04, blue: 0.18), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // ── Step content ──────────────────────────────────────────────────────
            Group {
                switch viewModel.currentStep {
                case .welcome:
                    WelcomeView(onContinue: {
                        withAnimation(.spring(duration: 0.45, bounce: 0.1)) {
                            viewModel.moveToNext()
                        }
                    })

                case .permissions:
                    PermissionView(onContinue: {
                        withAnimation(.spring(duration: 0.45, bounce: 0.1)) {
                            viewModel.moveToNext()
                        }
                    })

                case .createAlbum:
                    CreateFirstAlbumView(onComplete: {
                        withAnimation(.spring(duration: 0.45, bounce: 0.1)) {
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
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }
}

#Preview {
    OnboardingFlow(onboardingComplete: .constant(false))
}
