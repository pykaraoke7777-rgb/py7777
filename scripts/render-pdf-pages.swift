import AppKit
import Foundation
import PDFKit

struct Options {
    let input: String
    let output: String
    let width: CGFloat
    let quality: CGFloat
}

func parseOptions() -> Options? {
    let args = CommandLine.arguments
    guard args.count >= 3 else { return nil }

    let width = args.count >= 4 ? CGFloat(Double(args[3]) ?? 1100) : 1100
    let quality = args.count >= 5 ? CGFloat(Double(args[4]) ?? 0.72) : 0.72

    return Options(input: args[1], output: args[2], width: width, quality: quality)
}

guard let options = parseOptions() else {
    FileHandle.standardError.write(
        "Usage: swift render-pdf-pages.swift input.pdf output-dir [width] [jpeg-quality]\n".data(using: .utf8)!
    )
    exit(1)
}

let inputURL = URL(fileURLWithPath: options.input)
let outputURL = URL(fileURLWithPath: options.output, isDirectory: true)

guard let document = PDFDocument(url: inputURL) else {
    FileHandle.standardError.write("Could not open PDF: \(options.input)\n".data(using: .utf8)!)
    exit(1)
}

try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let pageCount = document.pageCount
let colorSpace = CGColorSpaceCreateDeviceRGB()
var manifest: [[String: Any]] = []

for pageIndex in 0..<pageCount {
    guard let page = document.page(at: pageIndex) else { continue }

    let pageNumber = pageIndex + 1
    let box = page.bounds(for: .mediaBox)
    let scale = options.width / box.width
    let pixelWidth = Int((box.width * scale).rounded())
    let pixelHeight = Int((box.height * scale).rounded())

    guard let context = CGContext(
        data: nil,
        width: pixelWidth,
        height: pixelHeight,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        FileHandle.standardError.write("Could not create bitmap context for page \(pageNumber)\n".data(using: .utf8)!)
        exit(1)
    }

    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
    context.interpolationQuality = .high

    context.saveGState()
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -box.minX, y: -box.minY)
    page.draw(with: .mediaBox, to: context)
    context.restoreGState()

    guard let image = context.makeImage() else {
        FileHandle.standardError.write("Could not create image for page \(pageNumber)\n".data(using: .utf8)!)
        exit(1)
    }

    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: options.quality]) else {
        FileHandle.standardError.write("Could not encode JPEG for page \(pageNumber)\n".data(using: .utf8)!)
        exit(1)
    }

    let filename = String(format: "page-%02d.jpg", pageNumber)
    let pageURL = outputURL.appendingPathComponent(filename)
    try data.write(to: pageURL)

    manifest.append([
        "page": pageNumber,
        "src": "pages/\(filename)",
        "width": pixelWidth,
        "height": pixelHeight,
        "bytes": data.count
    ])

    print("Rendered \(filename) \(pixelWidth)x\(pixelHeight) \(data.count) bytes")
}

let manifestData = try JSONSerialization.data(
    withJSONObject: ["pages": manifest],
    options: [.prettyPrinted, .sortedKeys]
)
try manifestData.write(to: outputURL.deletingLastPathComponent().appendingPathComponent("pages.json"))
