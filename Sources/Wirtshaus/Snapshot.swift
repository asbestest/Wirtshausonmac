import AppKit

/// Offscreen renders for checking the artwork and building the app icon (`--snapshot`, `--icon`).
enum Snapshot {
    /// Both decks, the backs, and the props at two moments, on one sheet.
    static func sheet(to path: String) {
        let h: CGFloat = 175, gap: CGFloat = 12
        let rows: [[(ItemFace, Double)]] = [
            Deck.french.cards.map { (.card(.french, $0.rank, $0.suit), 0) },
            Deck.bavarian.cards.map { (.card(.bavarian, $0.rank, $0.suit), 0) },
            CardBack.allCases.map { (.back(.french, $0), 0) } + [(.back(.bavarian, .blue), 0)],
            Prop.allCases.map { (.prop($0), 1.5) },
            Prop.allCases.map { (.prop($0), 3.9) },
        ]
        let rowWidth = rows.map { $0.reduce(gap) { $0 + h * CardArt.aspect($1.0) + gap } }.max()!
        let size = CGSize(width: rowWidth, height: CGFloat(rows.count) * (h + gap) + gap)
        write(size: size, to: path) { ctx in
            ctx.setFillColor(CGColor(red: 0.13, green: 0.36, blue: 0.24, alpha: 1))
            ctx.fill(CGRect(origin: .zero, size: size))
            for (r, row) in rows.enumerated() {
                var x = gap
                let y = size.height - CGFloat(r + 1) * (h + gap)
                for (face, t) in row {
                    let w = h * CardArt.aspect(face)
                    CardArt.draw(face, at: t, in: ctx, rect: CGRect(x: x, y: y, width: w, height: h))
                    x += w + gap
                }
            }
        }
    }

    /// 1024 px app icon: a felt tile with two fanned cards.
    static func icon(to path: String) {
        let s: CGFloat = 1024
        write(size: CGSize(width: s, height: s), to: path) { ctx in
            let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                              cornerWidth: 185, cornerHeight: 185, transform: nil)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: CGColor(gray: 0, alpha: 0.35))
            ctx.addPath(tile)
            ctx.setFillColor(CGColor(red: 0.1, green: 0.4, blue: 0.27, alpha: 1))
            ctx.fillPath()
            ctx.restoreGState()
            ctx.saveGState()
            ctx.addPath(tile)
            ctx.clip()
            let grad = CGGradient(colorsSpace: nil, colors: [
                CGColor(red: 0.17, green: 0.55, blue: 0.37, alpha: 1),
                CGColor(red: 0.06, green: 0.3, blue: 0.2, alpha: 1),
            ] as CFArray, locations: [0, 1])!
            ctx.drawRadialGradient(grad, startCenter: CGPoint(x: 512, y: 600), startRadius: 0,
                                   endCenter: CGPoint(x: 512, y: 512), endRadius: 620, options: .drawsAfterEndLocation)

            let ch: CGFloat = 560, cw = ch * 250 / 350
            for (face, angle, dx) in [(ItemFace.back(.french, .red), 0.24, -95.0), (.card(.french, .ace, 1), -0.12, 80.0)] as [(ItemFace, CGFloat, CGFloat)] {
                ctx.saveGState()
                ctx.translateBy(x: 512 + dx, y: 470)
                ctx.rotate(by: angle)
                ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: CGColor(gray: 0, alpha: 0.45))
                ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                CardArt.draw(face, in: ctx, rect: CGRect(x: -cw / 2, y: -ch / 2, width: cw, height: ch))
                ctx.endTransparencyLayer()
                ctx.restoreGState()
            }
            // a Maß in front: it's a Wirtshaus after all
            ctx.saveGState()
            ctx.translateBy(x: 150, y: 150)
            ctx.scaleBy(x: 1.15, y: 1.15)
            ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 22, color: CGColor(gray: 0, alpha: 0.4))
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            PropArt.draw(.beer, t: 2.2, ctx)
            ctx.endTransparencyLayer()
            ctx.restoreGState()
            ctx.restoreGState()
        }
    }

    /// Turned items as the window draws them, with a red dot wherever a click would be taken.
    static func turned(to path: String) {
        let cases: [(ItemFace, CGFloat)] = [(.card(.bavarian, .ober, 1), 25), (.card(.french, .jack, 0), -90), (.prop(.beer), -20), (.prop(.cigarette), 40)]
        let size = CGSize(width: 1100, height: 330)
        write(size: size, to: path) { ctx in
            ctx.setFillColor(CGColor(gray: 0.85, alpha: 1))
            ctx.fill(CGRect(origin: .zero, size: size))
            var x: CGFloat = 20
            for (face, angle) in cases {
                var item = ItemState()
                if case .prop(let p) = face { item.prop = p }
                if case .card(_, let r, let s) = face { item.rank = r; item.suit = s }
                let deck: Deck = { if case .card(let d, _, _) = face { return d }; return .french }()
                item.height = 200
                item.angle = Double(angle)
                let f = CardWindow.frame(for: item, deck: deck)
                let view = CardView(frame: NSRect(origin: .zero, size: f.size))
                view.face = face
                view.itemSize = CardWindow.size(of: item, deck: deck)
                view.angle = angle
                ctx.saveGState()
                ctx.translateBy(x: x, y: 40)
                ctx.setStrokeColor(CGColor(gray: 0.5, alpha: 1))
                ctx.stroke(CGRect(origin: .zero, size: f.size))
                // the same path the window takes: the face rendered into the layer's contents
                view.updateLayer()
                if let img = view.layer?.contents { ctx.draw(img as! CGImage, in: CGRect(origin: .zero, size: f.size)) }
                ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 0.6))
                for gx in stride(from: 0, to: f.width, by: 10) {
                    for gy in stride(from: 0, to: f.height, by: 10) where view.isSolid(at: NSPoint(x: gx, y: gy)) {
                        ctx.fillEllipse(in: CGRect(x: gx - 1, y: gy - 1, width: 2, height: 2))
                    }
                }
                ctx.restoreGState()
                x += f.width + 30
            }
        }
    }

    private static func write(size: CGSize, to path: String, _ body: (CGContext) -> Void) {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        body(NSGraphicsContext.current!.cgContext)
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
