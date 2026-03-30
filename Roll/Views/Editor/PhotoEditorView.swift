import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct PhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    @State private var selectedTool: EditorTool = .filters
    @State private var editedImage: UIImage
    @State private var originalImage: UIImage

    // Adjustment values
    @State private var brightness: Double = 0
    @State private var contrast: Double = 1
    @State private var saturation: Double = 1

    // Filter
    @State private var selectedFilter: String = "Original"

    private let context = CIContext()

    enum EditorTool: String, CaseIterable {
        case filters = "Filters"
        case adjust = "Adjust"
        case crop = "Crop"
    }

    init(image: UIImage) {
        self.image = image
        _editedImage = State(initialValue: image)
        _originalImage = State(initialValue: image)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview
                Image(uiImage: editedImage)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .frame(maxHeight: 400)

                // Tool picker
                Picker("Tool", selection: $selectedTool) {
                    ForEach(EditorTool.allCases, id: \.self) { tool in
                        Text(tool.rawValue).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // Tool content
                ScrollView {
                    switch selectedTool {
                    case .filters:
                        filterControls
                    case .adjust:
                        adjustmentControls
                    case .crop:
                        CropView(image: $editedImage)
                    }
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)

                    Button("Reset") {
                        editedImage = originalImage
                        brightness = 0
                        contrast = 1
                        saturation = 1
                        selectedFilter = "Original"
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(8)

                    Button("Save") {
                        PhotoLibraryService.shared.savePhotoToLibrary(editedImage, toAlbum: "Edited") { _, _ in
                            DispatchQueue.main.async { dismiss() }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(16)
            }
            .navigationTitle("Edit Photo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var filterControls: some View {
        let filters = ["Original", "Mono", "Sepia", "Noir", "Fade", "Chrome", "Instant", "Process"]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
            ForEach(filters, id: \.self) { filterName in
                Button(action: {
                    selectedFilter = filterName
                    applyFilter(filterName)
                }) {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 60)
                            .overlay(
                                Text(String(filterName.prefix(3)))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedFilter == filterName ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        Text(filterName)
                            .font(.caption2)
                            .foregroundColor(selectedFilter == filterName ? .blue : .primary)
                    }
                }
            }
        }
        .padding(16)
    }

    private var adjustmentControls: some View {
        VStack(spacing: 20) {
            adjustmentSlider(title: "Brightness", value: $brightness, range: -0.5...0.5)
            adjustmentSlider(title: "Contrast", value: $contrast, range: 0.5...1.5)
            adjustmentSlider(title: "Saturation", value: $saturation, range: 0...2)
        }
        .padding(16)
        .onChange(of: brightness) { applyAdjustments() }
        .onChange(of: contrast) { applyAdjustments() }
        .onChange(of: saturation) { applyAdjustments() }
    }

    private func adjustmentSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: range)
                .tint(.blue)
        }
    }

    private func applyFilter(_ name: String) {
        guard let ciImage = CIImage(image: originalImage) else { return }
        var outputImage: CIImage?

        switch name {
        case "Mono":
            let filter = CIFilter(name: "CIPhotoEffectMono")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            outputImage = filter?.outputImage
        case "Sepia":
            let filter = CIFilter(name: "CISepiaTone")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(0.8, forKey: kCIInputIntensityKey)
            outputImage = filter?.outputImage
        case "Noir":
            let filter = CIFilter(name: "CIPhotoEffectNoir")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            outputImage = filter?.outputImage
        case "Fade":
            let filter = CIFilter(name: "CIPhotoEffectFade")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            outputImage = filter?.outputImage
        case "Chrome":
            let filter = CIFilter(name: "CIPhotoEffectChrome")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            outputImage = filter?.outputImage
        case "Instant":
            let filter = CIFilter(name: "CIPhotoEffectInstant")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            outputImage = filter?.outputImage
        case "Process":
            let filter = CIFilter(name: "CIPhotoEffectProcess")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            outputImage = filter?.outputImage
        default:
            editedImage = originalImage
            return
        }

        if let output = outputImage, let cgImage = context.createCGImage(output, from: output.extent) {
            editedImage = UIImage(cgImage: cgImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
        }
    }

    private func applyAdjustments() {
        guard let ciImage = CIImage(image: originalImage) else { return }

        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter?.setValue(contrast, forKey: kCIInputContrastKey)
        filter?.setValue(saturation, forKey: kCIInputSaturationKey)

        if let output = filter?.outputImage, let cgImage = context.createCGImage(output, from: output.extent) {
            editedImage = UIImage(cgImage: cgImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
        }
    }
}

#Preview {
    PhotoEditorView(image: UIImage(systemName: "photo") ?? UIImage())
}
