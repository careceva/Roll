import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct PhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    @State private var selectedTool: EditorTool = .filters
    @State private var editedImage: UIImage
    @State private var originalImage: UIImage

    // Adjustment values (unchanged)
    @State private var brightness: Double = 0
    @State private var contrast:   Double = 1
    @State private var saturation: Double = 1

    @State private var selectedFilter: String = "Original"

    private let context = CIContext()

    enum EditorTool: String, CaseIterable {
        case filters = "Filters"
        case adjust  = "Adjust"
        case crop    = "Crop"
    }

    init(image: UIImage) {
        self.image = image
        _editedImage   = State(initialValue: image)
        _originalImage = State(initialValue: image)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Preview ───────────────────────────────────────────────
                Image(uiImage: editedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.separator, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // ── Tool segmented picker ─────────────────────────────────
                Picker("Tool", selection: $selectedTool) {
                    ForEach(EditorTool.allCases, id: \.self) { tool in
                        Text(tool.rawValue).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                // ── Tool content ──────────────────────────────────────────
                ScrollView {
                    switch selectedTool {
                    case .filters: filterControls
                    case .adjust:  adjustmentControls
                    case .crop:    CropView(image: $editedImage)
                    }
                }

                // ── Action bar — iOS 26 glass ─────────────────────────────
                HStack(spacing: 10) {
                    Button("Cancel") { dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button("Reset") {
                        editedImage  = originalImage
                        brightness   = 0
                        contrast     = 1
                        saturation   = 1
                        selectedFilter = "Original"
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.orange)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button("Save") {
                        PhotoLibraryService.shared.savePhotoToLibrary(
                            editedImage, toAlbum: "Edited"
                        ) { _, _ in
                            DispatchQueue.main.async { dismiss() }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .navigationTitle("Edit Photo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Filter controls (unchanged logic, iOS 26 styling)

    private var filterControls: some View {
        let filters = ["Original", "Mono", "Sepia", "Noir", "Fade", "Chrome", "Instant", "Process"]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
            ForEach(filters, id: \.self) { filterName in
                Button(action: {
                    selectedFilter = filterName
                    applyFilter(filterName)
                }) {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.systemGray5))
                            .frame(height: 56)
                            .overlay(
                                Text(String(filterName.prefix(3)))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        selectedFilter == filterName ? Color.accentColor : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                        Text(filterName)
                            .font(.caption2)
                            .foregroundStyle(
                                selectedFilter == filterName ? Color.accentColor : Color.primary
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    // MARK: - Adjustment controls (unchanged logic, iOS 26 styling)

    private var adjustmentControls: some View {
        VStack(spacing: 20) {
            adjustmentSlider(title: "Brightness", value: $brightness, range: -0.5...0.5)
            adjustmentSlider(title: "Contrast",   value: $contrast,   range: 0.5...1.5)
            adjustmentSlider(title: "Saturation", value: $saturation, range: 0...2)
        }
        .padding(16)
        .onChange(of: brightness) { applyAdjustments() }
        .onChange(of: contrast)   { applyAdjustments() }
        .onChange(of: saturation) { applyAdjustments() }
    }

    private func adjustmentSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .tint(.accentColor)
        }
    }

    // MARK: - Core Image processing (unchanged)

    private func applyFilter(_ name: String) {
        guard let ciImage = CIImage(image: originalImage) else { return }
        var outputImage: CIImage?

        switch name {
        case "Mono":
            let f = CIFilter(name: "CIPhotoEffectMono"); f?.setValue(ciImage, forKey: kCIInputImageKey); outputImage = f?.outputImage
        case "Sepia":
            let f = CIFilter(name: "CISepiaTone"); f?.setValue(ciImage, forKey: kCIInputImageKey); f?.setValue(0.8, forKey: kCIInputIntensityKey); outputImage = f?.outputImage
        case "Noir":
            let f = CIFilter(name: "CIPhotoEffectNoir"); f?.setValue(ciImage, forKey: kCIInputImageKey); outputImage = f?.outputImage
        case "Fade":
            let f = CIFilter(name: "CIPhotoEffectFade"); f?.setValue(ciImage, forKey: kCIInputImageKey); outputImage = f?.outputImage
        case "Chrome":
            let f = CIFilter(name: "CIPhotoEffectChrome"); f?.setValue(ciImage, forKey: kCIInputImageKey); outputImage = f?.outputImage
        case "Instant":
            let f = CIFilter(name: "CIPhotoEffectInstant"); f?.setValue(ciImage, forKey: kCIInputImageKey); outputImage = f?.outputImage
        case "Process":
            let f = CIFilter(name: "CIPhotoEffectProcess"); f?.setValue(ciImage, forKey: kCIInputImageKey); outputImage = f?.outputImage
        default:
            editedImage = originalImage
            return
        }

        if let output = outputImage,
           let cgImage = context.createCGImage(output, from: output.extent) {
            editedImage = UIImage(
                cgImage: cgImage,
                scale: originalImage.scale,
                orientation: originalImage.imageOrientation
            )
        }
    }

    private func applyAdjustments() {
        guard let ciImage = CIImage(image: originalImage) else { return }
        let f = CIFilter(name: "CIColorControls")
        f?.setValue(ciImage,     forKey: kCIInputImageKey)
        f?.setValue(brightness,  forKey: kCIInputBrightnessKey)
        f?.setValue(contrast,    forKey: kCIInputContrastKey)
        f?.setValue(saturation,  forKey: kCIInputSaturationKey)
        if let output = f?.outputImage,
           let cgImage = context.createCGImage(output, from: output.extent) {
            editedImage = UIImage(
                cgImage: cgImage,
                scale: originalImage.scale,
                orientation: originalImage.imageOrientation
            )
        }
    }
}

#Preview {
    PhotoEditorView(image: UIImage(systemName: "photo") ?? UIImage())
}
