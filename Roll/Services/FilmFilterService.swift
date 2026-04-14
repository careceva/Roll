import UIKit
import CoreImage

struct FilmFilter: Identifiable {
    let id: String
    let name: String
    let category: String
    let fileName: String
}

final class FilmFilterService {
    static let shared = FilmFilterService()

    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private var cubeDataCache: [String: Data] = [:]

    let filters: [FilmFilter] = [
        // Color Negative
        FilmFilter(id: "portra160", name: "Portra 160", category: "Color", fileName: "kodak_portra_160"),
        FilmFilter(id: "portra160vc", name: "Portra 160 VC", category: "Color", fileName: "kodak_portra_160_vc"),
        FilmFilter(id: "gold200", name: "Gold 200", category: "Color", fileName: "kodak_gold_200"),
        FilmFilter(id: "superia200", name: "Superia 200", category: "Color", fileName: "fuji_superia_200"),
        FilmFilter(id: "vista200", name: "Vista 200", category: "Color", fileName: "agfa_vista_200"),

        // Color Slide
        FilmFilter(id: "velvia50", name: "Velvia 50", category: "Slide", fileName: "fuji_velvia_50"),
        FilmFilter(id: "kodachrome64", name: "Kodachrome 64", category: "Slide", fileName: "kodak_kodachrome_64"),
        FilmFilter(id: "provia100f", name: "Provia 100F", category: "Slide", fileName: "fuji_provia_100f"),

        // B&W
        FilmFilter(id: "trix400", name: "Tri-X 400", category: "B&W", fileName: "kodak_trix_400"),
        FilmFilter(id: "hp5400", name: "HP5 400", category: "B&W", fileName: "ilford_hp5_400"),
        FilmFilter(id: "acros100", name: "Acros 100", category: "B&W", fileName: "fuji_acros_100"),
    ]

    private init() {}

    func applyFilter(_ filter: FilmFilter, to image: UIImage) -> UIImage? {
        guard let ciInput = CIImage(image: image) else { return nil }
        guard let cubeData = loadCubeData(for: filter) else { return nil }

        let dimension = 64 // 512x512 HaldCLUT = level 8 = 64^3

        let colorCube = CIFilter(name: "CIColorCubeWithColorSpace")!
        colorCube.setValue(dimension, forKey: "inputCubeDimension")
        colorCube.setValue(cubeData, forKey: "inputCubeData")
        colorCube.setValue(CGColorSpaceCreateDeviceRGB(), forKey: "inputColorSpace")
        colorCube.setValue(ciInput, forKey: kCIInputImageKey)

        guard let output = colorCube.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - HaldCLUT to CubeData conversion

    private func loadCubeData(for filter: FilmFilter) -> Data? {
        if let cached = cubeDataCache[filter.id] { return cached }

        guard let url = Bundle.main.url(forResource: filter.fileName, withExtension: "png"),
              let clutImage = UIImage(contentsOfFile: url.path),
              let cgImage = clutImage.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width == 512, height == 512 else { return nil }

        // Extract pixel data from HaldCLUT
        guard let pixelData = extractPixelData(from: cgImage, width: width, height: height) else {
            return nil
        }

        // Convert HaldCLUT pixel layout to 3D cube data
        // HaldCLUT level 8: 64x64x64 LUT stored as 512x512 image
        // Each pixel maps (r, g, b) input to (R, G, B) output
        let dimension = 64
        let cubeSize = dimension * dimension * dimension * 4 // RGBA floats
        var cubeFloats = [Float](repeating: 0, count: cubeSize)

        for b in 0..<dimension {
            for g in 0..<dimension {
                for r in 0..<dimension {
                    // Map (r, g, b) to pixel position in HaldCLUT
                    let index = r + g * dimension + b * dimension * dimension
                    let px = index % width
                    let py = index / width

                    let pixelIndex = (py * width + px) * 4
                    let cubeIndex = (r + g * dimension + b * dimension * dimension) * 4

                    cubeFloats[cubeIndex + 0] = Float(pixelData[pixelIndex + 0]) / 255.0
                    cubeFloats[cubeIndex + 1] = Float(pixelData[pixelIndex + 1]) / 255.0
                    cubeFloats[cubeIndex + 2] = Float(pixelData[pixelIndex + 2]) / 255.0
                    cubeFloats[cubeIndex + 3] = 1.0
                }
            }
        }

        let data = Data(bytes: cubeFloats, count: cubeFloats.count * MemoryLayout<Float>.size)
        cubeDataCache[filter.id] = data
        return data
    }

    private func extractPixelData(from cgImage: CGImage, width: Int, height: Int) -> [UInt8]? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
    }
}
