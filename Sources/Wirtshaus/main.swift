import AppKit
import SwiftUI

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--snapshot") {
    Snapshot.sheet(to: args.count > i + 1 ? args[i + 1] : "cards.png")
    exit(0)
}
if let i = args.firstIndex(of: "--icon") {
    Snapshot.icon(to: args.count > i + 1 ? args[i + 1] : "icon.png")
    exit(0)
}
if let i = args.firstIndex(of: "--turned") {
    Snapshot.turned(to: args.count > i + 1 ? args[i + 1] : "turned.png")
    exit(0)
}
if args.contains("--bench") {
    // Debug: milliseconds per frame for each prop, drawn at 180 pt on a Retina screen.
    for p in Prop.allCases {
        let face = ItemFace.prop(p), h: CGFloat = 360, w = (h * CardArt.aspect(face)).rounded()
        let ctx = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let start = CACurrentMediaTime()
        for f in 0..<100 {
            ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
            CardArt.draw(face, at: Double(f) / 24, in: ctx, rect: CGRect(x: 0, y: 0, width: w, height: h))
        }
        print(p.title, String(format: "%.2f ms", (CACurrentMediaTime() - start) * 10))
    }
    exit(0)
}
if let i = args.firstIndex(of: "--settings") {
    // Debug: the settings window, rendered offscreen.
    let host = NSHostingView(rootView: SettingsView(store: CardStore()))
    host.frame.size = host.fittingSize
    if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: args.count > i + 1 ? args[i + 1] : "settings.png"))
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
