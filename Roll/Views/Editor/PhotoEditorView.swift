import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct PhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    var albumName: String = ""
    @State private var selectedTool: EditorTool = .filters
    @State private var editedImage: UIImage
    @State private var originalImage: UIImage

    // Adjustment values
    @State private var brightness: Double = 0
    @State private var contrast:   Double = 1
    @State private var saturation: Double = 1

    @State private var selectedFilter: String = "Original"
    @State private var isProcessing = false

    private let context = CIContext()
    private let filmService = FilmFilterService.shared

    enum EditorTool: String, CaseIterable {
        case filters = "Filters"
        case adjust  = "Adjust"
        case crop    = "Crop"
    }

    init(image: UIImage, albumName: String = "") {
        self.image = image
        self.albumName = albumName
        _editedImage   = State(initialValue: image)
        _originalImage = State(initialValue: image)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Preview ───────────────────────────────────────────────
                ZStack {
                    Image(uiImage: editedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(.separator, lineWidth: 0.5)
                        )

                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    }
                }
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

                // ── Action bar ───────────────────────────────────────────
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
                            editedImage, toAlbum: albumName
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

    // MARK: - Filter Controls

    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Film filters
            Text("FILM")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Original (no filter)
                    filterButton(id: "Original", label: "Original")

                    // Film stock filters
                    ForEach(filmService.filters) { film in
                        filterButton(id: film.id, label: film.name)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Basic CIFilter presets
            Text("BASIC")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(["Mono", "Sepia", "Noir", "Fade", "Chrome", "Instant", "Process"], id: \.self) { name in
                        filterButton(id: name, label: name)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
    }

    private func filterButton(id: String, label: String) -> some View {
        Button {
            guard !isProcessing else { return }
            selectedFilter = id
            applySelectedFilter(id)
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.systemGray5))
                    .frame(width: 72, height: 56)
                    .overlay(
                        Text(String(label.prefix(4)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                selectedFilter == id ? Color.accentColor : Color.clear,
                                lineWidth: 2
                            )
                    )
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(
                        selectedFilter == id ? Color.accentColor : Color.primary
                    )
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Adjustment controls

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

    // MARK: - Filter Application

    private func applySelectedFilter(_ id: String) {
        if id == "Original" {
            editedImage = originalImage
            return
        }

        // Check if it's a film filter
        if let film = filmService.filters.first(where: { $0.id == id }) {
            isProcessing = true
            DispatchQueue.global(qos: .userInitiated).async {
                let result = filmService.applyFilter(film, to: originalImage)
                DispatchQueue.main.async {
                    if let result { editedImage = result }
                    isProcessing = false
                }
            }
            return
        }

        // Basic CIFilter presets
        applyCIFilter(id)
    }

    private func applyCIFilter(_ name: String) {
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
