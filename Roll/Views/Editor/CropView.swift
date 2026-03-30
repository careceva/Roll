import SwiftUI

struct CropView: View {
    @Binding var image: UIImage
    @State private var selectedAspectRatio: AspectRatio = .square
    @State private var rotation: Double = 0

    enum AspectRatio: String, CaseIterable {
        case freeform = "Free"
        case square = "1:1"
        case threeTwo = "3:2"
        case fourThree = "4:3"
        case sixteenNine = "16:9"

        var ratio: CGFloat? {
            switch self {
            case .freeform:
                return nil
            case .square:
                return 1
            case .threeTwo:
                return 3.0 / 2.0
            case .fourThree:
                return 4.0 / 3.0
            case .sixteenNine:
                return 16.0 / 9.0
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Text("Aspect Ratio")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    ForEach(AspectRatio.allCases, id: \.self) { ratio in
                        Button(action: { selectedAspectRatio = ratio }) {
                            Text(ratio.rawValue)
                                .font(.caption)
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(selectedAspectRatio == ratio ? Color.blue : Color.gray.opacity(0.3))
                                .foregroundColor(selectedAspectRatio == ratio ? .white : .primary)
                                .cornerRadius(6)
                        }
                    }
                }
            }

            VStack(spacing: 12) {
                HStack {
                    Text("Rotate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(rotation))°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Slider(value: $rotation, in: 0...360)
                    .tint(.blue)
            }

            Button(action: { rotation = 0 }) {
                Text("Reset")
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(6)
            }

            Spacer()
        }
        .padding(16)
    }
}

#Preview {
    CropView(image: .constant(UIImage(systemName: "photo") ?? UIImage()))
}
