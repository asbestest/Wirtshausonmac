// Cuts the Schafkopf cards (Sau, Ober, Unter of each suit) out of a picture of the whole
// Bavarian deck: 4 rows (Eichel, Gras, Herz, Schellen) × 8 columns (Sau, 10, König, Ober, Unter, 9, 8, 7)
// on a dark background. Writes Resources/bavarian/<suit>-<rank>.jpg.
// Small cards (under 600 px tall) are upscaled with MetalFX and lightly sharpened, so they stay crisp
// at large sizes; a high-resolution picture of the deck is still the better source.
// Usage: swift scripts/crop-bavarian.swift Artwork/bayerisches-blatt.webp
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Metal
import MetalFX
import MetalKit
import UniformTypeIdentifiers

let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!

/// Edge-aware upscaling by `factor` (MetalFX spatial scaler), then a gentle unsharp mask.
func upscale(_ image: CGImage, by factor: Int) -> CGImage {
    let input = try! MTKTextureLoader(device: device).newTexture(cgImage: image, options: [
        .SRGB: false, .textureUsage: MTLTextureUsage.shaderRead.rawValue, .textureStorageMode: MTLStorageMode.private.rawValue,
    ])
    let ow = image.width * factor, oh = image.height * factor
    let desc = MTLFXSpatialScalerDescriptor()
    desc.inputWidth = image.width; desc.inputHeight = image.height
    desc.outputWidth = ow; desc.outputHeight = oh
    desc.colorTextureFormat = input.pixelFormat; desc.outputTextureFormat = input.pixelFormat
    desc.colorProcessingMode = .perceptual
    let scaler = desc.makeSpatialScaler(device: device)!
    let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: input.pixelFormat, width: ow, height: oh, mipmapped: false)
    td.usage = scaler.outputTextureUsage
    td.storageMode = .private
    let output = device.makeTexture(descriptor: td)!
    let sd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: input.pixelFormat, width: ow, height: oh, mipmapped: false)
    sd.storageMode = .shared
    let readback = device.makeTexture(descriptor: sd)!
    scaler.colorTexture = input
    scaler.outputTexture = output
    let cb = queue.makeCommandBuffer()!
    scaler.encode(commandBuffer: cb)
    let blit = cb.makeBlitCommandEncoder()!
    blit.copy(from: output, to: readback)
    blit.endEncoding()
    cb.commit()
    cb.waitUntilCompleted()

    var ci = CIImage(mtlTexture: readback, options: [.colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])!
        .transformed(by: CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -CGFloat(oh)))   // textures are top-down
    ci = ci.applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: 1.6 * Double(factor) / 4, kCIInputIntensityKey: 0.45])
    return CIContext().createCGImage(ci, from: CGRect(x: 0, y: 0, width: ow, height: oh))!
}

let args = CommandLine.arguments
guard args.count > 1, let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let sheet = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    print("usage: swift scripts/crop-bavarian.swift <sheet image>"); exit(1)
}
let w = sheet.width, h = sheet.height
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(sheet, in: CGRect(x: 0, y: 0, width: w, height: h))
let px = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
/// Light pixels belong to cards (white paper), the background is dark green. Row 0 is the top.
func light(_ x: Int, _ y: Int) -> Bool {
    let i = (y * w + x) * 4
    return Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2]) > 600
}

/// Runs of rows/columns that aren't background: a line counts as gap when almost none of it is light.
func runs(count: Int, length: Int, _ isLight: (Int, Int) -> Bool) -> [Range<Int>] {
    var result: [Range<Int>] = [], start: Int?
    for i in 0...count {
        let on = i < count && Double((0..<length).filter { isLight(i, $0) }.count) > Double(length) * 0.03
        if on, start == nil { start = i }
        if !on, let s = start { if i - s > 20 { result.append(s..<i) }; start = nil }
    }
    return result
}

let cols = runs(count: w, length: h) { x, y in light(x, y) }
let rows = runs(count: h, length: w) { y, x in light(x, y) }
print("columns: \(cols.map { "\($0.lowerBound)-\($0.upperBound)" })")
print("rows: \(rows.map { "\($0.lowerBound)-\($0.upperBound)" })")
guard cols.count == 8, rows.count == 4 else { print("expected 8 columns and 4 rows"); exit(1) }

let out = URL(fileURLWithPath: "Resources/bavarian")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for (suit, row) in rows.enumerated() {
    for (rank, col) in [("sau", 0), ("ober", 3), ("unter", 4)] {
        // 1 px in, so no background bleeds into the edge
        let r = CGRect(x: cols[col].lowerBound + 1, y: row.lowerBound + 1,
                       width: cols[col].count - 2, height: row.count - 2)
        guard let cut = sheet.cropping(to: r) else { continue }
        let card = cut.height < 600 ? upscale(cut, by: 4) : cut
        let cw = card.width, ch = card.height
        // JPEG keeps the app small; the app rounds the corners itself when it draws the card
        let url = out.appendingPathComponent("\(suit)-\(rank).jpg")
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, card, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
        CGImageDestinationFinalize(dest)
        print("wrote \(url.lastPathComponent) \(cw)×\(ch)")
    }
}
