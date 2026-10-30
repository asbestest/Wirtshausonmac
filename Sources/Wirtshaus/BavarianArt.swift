import CoreGraphics
import Foundation
import ImageIO

/// The Bavarian deck (Schafkopf): Eichel, Gras, Herz, Schellen; Ober, Unter and Sau.
/// Uses the card pictures in Resources/bavarian (cut out by scripts/crop-bavarian.swift);
/// a card without a picture is drawn: the Ober holds his suit up high, the Unter low,
/// and the Sau (the Daus) shows its suit twice.
enum BavarianArt {
    private static let H = CardArt.H

    /// "<suit>-<ober|unter|sau>" → picture file. Only the paths are kept; pixels are decoded on demand.
    private static let files: [String: URL] = {
        var dirs = [Bundle.main.resourceURL?.appendingPathComponent("bavarian")]
        dirs.append(URL(fileURLWithPath: "Resources/bavarian"))   // running from the project folder
        guard let dir = dirs.compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let list = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [:] }
        var result: [String: URL] = [:]
        for f in list where ["jpg", "png"].contains(f.pathExtension) { result[f.deletingPathExtension().lastPathComponent] = f }
        return result
    }()

    /// Decoded pictures at the sizes in use; small, so memory stays flat however many cards lie around.
    private static let cache: NSCache<NSString, CGImage> = {
        let c = NSCache<NSString, CGImage>()
        c.countLimit = 8
        return c
    }()

    /// The picture decoded just big enough for `pixels` of height (in steps of 64 px).
    private static func picture(_ rank: Rank, _ suit: Int, pixels: CGFloat) -> CGImage? {
        let name: String
        switch rank {
        case .ober: name = "ober"
        case .unter: name = "unter"
        case .sau: name = "sau"
        default: return nil
        }
        guard let url = files["\(suit)-\(name)"] else { return nil }
        let step = max(64, Int((pixels / 64).rounded(.up)) * 64)
        let key = "\(suit)-\(name)-\(step)" as NSString
        if let img = cache.object(forKey: key) { return img }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: step,
                  kCGImageSourceShouldCacheImmediately: true,
              ] as CFDictionary) else { return nil }
        cache.setObject(img, forKey: key)
        return img
    }

    /// Grid width: the pictures' shape (read from the file header, nothing decoded), or 222 for drawn cards.
    static let width: CGFloat = {
        guard let url = files.values.first, let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = p[kCGImagePropertyPixelWidth] as? CGFloat, let h = p[kCGImagePropertyPixelHeight] as? CGFloat else { return 222 }
        return H * w / h
    }()

    static func draw(rank: Rank, suit: Int, w: CGFloat, _ ctx: CGContext) {
        // device pixels the card's height covers (works for turned cards too)
        let t = ctx.userSpaceToDeviceSpaceTransform
        if let img = picture(rank, suit, pixels: H * hypot(t.c, t.d)) {
            let r = CGRect(x: 0, y: 0, width: w, height: H)
            ctx.saveGState()
            ctx.interpolationQuality = .high
            ctx.addPath(CardArt.outline(w: w, radius: w * 0.08))
            ctx.clip()
            ctx.draw(img, in: r)
            ctx.restoreGState()
            ctx.stroke(CardArt.outline(w: w, radius: w * 0.08), CardArt.edge, 1.2)
            return
        }
        CardArt.blankCard(w: w, radius: 12, ctx)
        // the thin printed frame
        ctx.stroke(roundRect(9, 9, w - 18, H - 18, 7), rgb(0.55, 0.45, 0.32, 0.55), 1.2)
        switch rank {
        case .sau: drawSau(suit: suit, w: w, ctx)
        default: drawFigure(suit: suit, ober: rank == .ober, w: w, ctx)
        }
    }

    // MARK: Suit symbols

    /// Draws a suit symbol in its colours, centered on `p`, about `s` units tall.
    static func pip(_ suit: Int, at p: CGPoint, size s: CGFloat, _ ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)
        ctx.scaleBy(x: s / 100, y: s / 100)   // symbols are drawn on a 100 grid around the origin
        switch suit {
        case 0: acorn(ctx)
        case 1: leaf(ctx)
        case 2: heart(ctx)
        default: bell(ctx)
        }
        ctx.restoreGState()
    }

    private static let outline = rgb(0.25, 0.15, 0.08)

    private static func acorn(_ ctx: CGContext) {
        // stem with a little leaf
        ctx.stroke(polyline([(0, 30), (3, 48)]), rgb(0.35, 0.22, 0.1), 5)
        let small = CGMutablePath()
        small.move(to: CGPoint(x: 3, y: 42))
        small.addQuadCurve(to: CGPoint(x: 26, y: 50), control: CGPoint(x: 12, y: 56))
        small.addQuadCurve(to: CGPoint(x: 3, y: 42), control: CGPoint(x: 18, y: 38))
        ctx.paint(small, rgb(0.3, 0.6, 0.25), line: 1.5, ink: outline)
        // nut
        let nut = ellipse(0, -12, 46, 74)
        ctx.gradient(nut, rgb(0.93, 0.78, 0.36), rgb(0.7, 0.5, 0.15))
        ctx.stroke(nut, outline, 2.4)
        ctx.fill(ellipse(-9, -16, 9, 30), rgb(1, 1, 1, 0.35))
        // cup, dotted like the real thing
        let cup = CGMutablePath()
        cup.move(to: CGPoint(x: -30, y: 12))
        cup.addCurve(to: CGPoint(x: 30, y: 12), control1: CGPoint(x: -32, y: 46), control2: CGPoint(x: 32, y: 46))
        cup.addQuadCurve(to: CGPoint(x: -30, y: 12), control: CGPoint(x: 0, y: 2))
        ctx.paint(cup, rgb(0.48, 0.3, 0.14), line: 2.4, ink: outline)
        ctx.setFillColor(rgb(0.75, 0.55, 0.3))
        for (x, y) in [(-18, 18), (-6, 16), (6, 16), (18, 18), (-12, 27), (0, 26), (12, 27), (-5, 35), (6, 35)] as [(CGFloat, CGFloat)] {
            ctx.fillEllipse(in: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5))
        }
    }

    private static func leaf(_ ctx: CGContext) {
        ctx.stroke(polyline([(0, -36), (4, -50)]), rgb(0.2, 0.4, 0.15), 5)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: 50))
        // slightly wavy edges like the Bavarian Gras leaf
        p.addCurve(to: CGPoint(x: 26, y: 16), control1: CGPoint(x: 12, y: 44), control2: CGPoint(x: 30, y: 32))
        p.addCurve(to: CGPoint(x: 34, y: -6), control1: CGPoint(x: 38, y: 10), control2: CGPoint(x: 40, y: 2))
        p.addCurve(to: CGPoint(x: 0, y: -38), control1: CGPoint(x: 30, y: -22), control2: CGPoint(x: 12, y: -34))
        p.addCurve(to: CGPoint(x: -34, y: -6), control1: CGPoint(x: -12, y: -34), control2: CGPoint(x: -30, y: -22))
        p.addCurve(to: CGPoint(x: -26, y: 16), control1: CGPoint(x: -40, y: 2), control2: CGPoint(x: -38, y: 10))
        p.addCurve(to: CGPoint(x: 0, y: 50), control1: CGPoint(x: -30, y: 32), control2: CGPoint(x: -12, y: 44))
        p.closeSubpath()
        ctx.gradient(p, rgb(0.42, 0.72, 0.3), rgb(0.16, 0.45, 0.17))
        ctx.stroke(p, rgb(0.08, 0.25, 0.08), 2.4)
        let veins = CGMutablePath()
        veins.move(to: CGPoint(x: 0, y: -38)); veins.addLine(to: CGPoint(x: 0, y: 42))
        for y in stride(from: -24, through: 24, by: 12) as StrideThrough<CGFloat> {
            veins.move(to: CGPoint(x: 0, y: y)); veins.addLine(to: CGPoint(x: 22 - abs(y) * 0.25, y: y + 12))
            veins.move(to: CGPoint(x: 0, y: y)); veins.addLine(to: CGPoint(x: -22 + abs(y) * 0.25, y: y + 12))
        }
        ctx.stroke(veins, rgb(0.08, 0.28, 0.08, 0.8), 1.6)
    }

    private static func heart(_ ctx: CGContext) {
        var t = CGAffineTransform(scaleX: 92, y: 92)
        let p = CardArt.suitPath(.hearts).copy(using: &t)!
        ctx.gradient(p, rgb(0.92, 0.25, 0.22), rgb(0.68, 0.06, 0.1))
        ctx.stroke(p, rgb(0.35, 0.02, 0.04), 2.4)
        ctx.fill(ellipse(-20, 16, 12, 18), rgb(1, 1, 1, 0.35))
    }

    private static func bell(_ ctx: CGContext) {
        ctx.stroke(ellipse(0, 40, 14, 12), outline, 4)
        let ball = ellipse(0, -4, 78, 78)
        ctx.gradient(ball, rgb(1, 0.85, 0.35), rgb(0.78, 0.52, 0.1))
        // red band around the middle
        ctx.saveGState()
        ctx.addPath(ball)
        ctx.clip()
        ctx.fill(CGPath(rect: CGRect(x: -45, y: 0, width: 90, height: 11), transform: nil), rgb(0.75, 0.13, 0.1))
        ctx.restoreGState()
        ctx.stroke(ball, outline, 2.4)
        ctx.fill(ellipse(-15, 12, 14, 10), rgb(1, 1, 1, 0.45))
        // the slit with its round ends
        ctx.stroke(polyline([(-16, -22), (16, -22)]), outline, 4)
        ctx.fill(ellipse(-17, -22, 9, 9), outline)
        ctx.fill(ellipse(17, -22, 9, 9), outline)
    }

    // MARK: Sau

    private static func drawSau(suit: Int, w: CGFloat, _ ctx: CGContext) {
        let cx = w / 2
        // laurel around the two symbols
        laurel(cx: cx, ctx)
        pip(suit, at: CGPoint(x: cx, y: 252), size: 96, ctx)
        pip(suit, at: CGPoint(x: cx, y: 150), size: 96, ctx)
        if suit == 3 {
            sow(cx: cx, y: 52, ctx)
        } else {
            // a ribbon at the foot
            let ribbon = CGMutablePath()
            ribbon.move(to: CGPoint(x: cx - 60, y: 60))
            ribbon.addQuadCurve(to: CGPoint(x: cx + 60, y: 60), control: CGPoint(x: cx, y: 44))
            ribbon.addLine(to: CGPoint(x: cx + 60, y: 78))
            ribbon.addQuadCurve(to: CGPoint(x: cx - 60, y: 78), control: CGPoint(x: cx, y: 62))
            ribbon.closeSubpath()
            ctx.paint(ribbon, suitColor(suit), line: 1.6)
            ctx.stroke(polyline([(cx - 40, 64), (cx + 40, 64)]), CardArt.gold, 1.4)
        }
    }

    private static func laurel(cx: CGFloat, _ ctx: CGContext) {
        let green = rgb(0.3, 0.55, 0.25)
        for side in [-1.0, 1.0] as [CGFloat] {
            let stem = CGMutablePath()
            stem.move(to: CGPoint(x: cx + side * 18, y: 92))
            stem.addQuadCurve(to: CGPoint(x: cx + side * 20, y: 318), control: CGPoint(x: cx + side * 92, y: 200))
            ctx.stroke(stem, rgb(0.25, 0.4, 0.18), 1.6)
            for i in 0..<9 {
                let t = CGFloat(i) / 8
                // point on the quad curve
                let x = (1 - t) * (1 - t) * (cx + side * 18) + 2 * (1 - t) * t * (cx + side * 92) + t * t * (cx + side * 20)
                let y = (1 - t) * (1 - t) * 92 + 2 * (1 - t) * t * 200 + t * t * 318
                ctx.saveGState()
                ctx.translateBy(x: x, y: y)
                ctx.rotate(by: side * (0.9 - t * 1.8) + (side > 0 ? 0 : .pi))
                ctx.paint(ellipse(8, 0, 16, 7), green, line: 0.8, ink: rgb(0.15, 0.3, 0.1))
                ctx.restoreGState()
            }
        }
    }

    /// The sow on the Schellen-Sau.
    private static func sow(cx: CGFloat, y: CGFloat, _ ctx: CGContext) {
        let pink = rgb(0.96, 0.7, 0.7), dark = rgb(0.45, 0.2, 0.2)
        ctx.fill(ellipse(cx, y - 18, 120, 8), rgb(0.3, 0.5, 0.2, 0.5))
        for x in [cx - 28, cx - 14, cx + 12, cx + 26] {
            ctx.paint(roundRect(x - 4, y - 20, 8, 18, 3), pink, line: 1.4, ink: dark)
        }
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: cx - 42, y: y + 6))
        tail.addCurve(to: CGPoint(x: cx - 52, y: y + 12), control1: CGPoint(x: cx - 52, y: y + 2), control2: CGPoint(x: cx - 56, y: y + 6))
        tail.addCurve(to: CGPoint(x: cx - 46, y: y + 16), control1: CGPoint(x: cx - 50, y: y + 18), control2: CGPoint(x: cx - 44, y: y + 20))
        ctx.stroke(tail, dark, 1.6)
        ctx.paint(ellipse(cx - 4, y + 4, 80, 40), pink, line: 1.6, ink: dark)
        ctx.paint(ellipse(cx + 38, y + 10, 30, 28), pink, line: 1.6, ink: dark)
        ctx.paint(polyline([(cx + 30, y + 20), (cx + 36, y + 34), (cx + 42, y + 22)], closed: true), pink, line: 1.4, ink: dark)
        ctx.paint(ellipse(cx + 54, y + 6, 12, 12), rgb(0.92, 0.55, 0.58), line: 1.4, ink: dark)
        ctx.fill(ellipse(cx + 52, y + 7, 2.5, 3), dark)
        ctx.fill(ellipse(cx + 56, y + 7, 2.5, 3), dark)
        ctx.fill(ellipse(cx + 42, y + 15, 3.5, 3.5), dark)
    }

    // MARK: Ober and Unter

    static func suitColor(_ suit: Int) -> CGColor {
        [rgb(0.58, 0.38, 0.16), rgb(0.2, 0.5, 0.25), rgb(0.74, 0.15, 0.17), rgb(0.88, 0.66, 0.15)][suit]
    }

    /// A standing figure. The Ober holds his symbol up and wears a feathered hat and beard,
    /// the Unter holds it low and wears a cap.
    private static func drawFigure(suit: Int, ober: Bool, w: CGFloat, _ ctx: CGContext) {
        let coat = suitColor(suit)
        let breeches = suit == 1 ? rgb(0.66, 0.16, 0.16) : rgb(0.2, 0.28, 0.55)
        let skin = rgb(0.96, 0.8, 0.65)
        let cx: CGFloat = 98

        ctx.fill(ellipse(cx + 4, 36, 110, 10), rgb(0, 0, 0, 0.12))

        // legs and shoes
        for x in [cx - 16, cx + 16] {
            ctx.paint(roundRect(x - 8, 42, 16, 80, 4), rgb(0.97, 0.94, 0.86), line: 1.6)
            ctx.paint(ellipse(x + 3, 40, 26, 11), rgb(0.15, 0.12, 0.1), line: 1.4)
        }
        ctx.paint(roundRect(cx - 27, 110, 54, 42, 10), breeches, line: 1.8)

        // the free arm: an Ober carries a sword, an Unter rests his hand on the hip
        if ober {
            ctx.stroke(polyline([(cx - 46, 168), (cx - 52, 58)]), rgb(0.6, 0.62, 0.66), 4)
            ctx.stroke(polyline([(cx - 58, 160), (cx - 36, 162)]), CardArt.gold, 4)
            arm([(cx - 24, 232), (cx - 38, 200), (cx - 46, 170)], coat, skin, ctx)
        } else {
            arm([(cx - 24, 232), (cx - 46, 200), (cx - 28, 172)], coat, skin, ctx)
        }

        // coat
        let body = CGMutablePath()
        body.move(to: CGPoint(x: cx - 26, y: 240))
        body.addLine(to: CGPoint(x: cx + 26, y: 240))
        body.addLine(to: CGPoint(x: cx + 36, y: 168))
        body.addQuadCurve(to: CGPoint(x: cx + 44, y: 128), control: CGPoint(x: cx + 46, y: 150))
        body.addQuadCurve(to: CGPoint(x: cx - 44, y: 128), control: CGPoint(x: cx, y: 118))
        body.addQuadCurve(to: CGPoint(x: cx - 36, y: 168), control: CGPoint(x: cx - 46, y: 150))
        body.closeSubpath()
        ctx.paint(body, coat, line: 2)
        ctx.stroke(polyline([(cx, 240), (cx, 124)]), CardArt.ink, 1.4)
        ctx.setFillColor(CardArt.gold)
        for y in stride(from: 222, through: 182, by: -14) as StrideThrough<CGFloat> {
            ctx.fillEllipse(in: CGRect(x: cx + 3, y: CGFloat(y) - 3, width: 6, height: 6))
        }
        ctx.paint(roundRect(cx - 37, 160, 74, 9, 2), rgb(0.3, 0.18, 0.1), line: 1.2)
        ctx.paint(roundRect(cx - 6, 158, 12, 13, 2), CardArt.gold, line: 1.2)
        // fur trim at the hem
        ctx.stroke(polyline([(cx - 43, 131), (cx, 122), (cx + 43, 131)]), rgb(0.95, 0.92, 0.84), 5)

        // the arm with the suit symbol
        if ober {
            arm([(cx + 24, 232), (cx + 46, 260), (cx + 58, 284)], coat, skin, ctx)
            pip(suit, at: CGPoint(x: cx + 70, y: 306), size: 60, ctx)
        } else {
            arm([(cx + 24, 232), (cx + 46, 196), (cx + 60, 158)], coat, skin, ctx)
            pip(suit, at: CGPoint(x: cx + 72, y: 118), size: 58, ctx)
        }

        // ruff, head, face
        ctx.paint(ellipse(cx, 242, 60, 16), rgb(0.98, 0.97, 0.94), line: 1.6)
        ctx.paint(ellipse(cx, 264, 36, 40), skin, line: 1.8)
        let hair = rgb(0.35, 0.22, 0.12)
        if ober {
            // full beard, grey on the Eichel-Ober (der Alte)
            let beard = CGMutablePath()
            beard.move(to: CGPoint(x: cx - 17, y: 262))
            beard.addQuadCurve(to: CGPoint(x: cx, y: 236), control: CGPoint(x: cx - 18, y: 238))
            beard.addQuadCurve(to: CGPoint(x: cx + 17, y: 262), control: CGPoint(x: cx + 18, y: 238))
            beard.addQuadCurve(to: CGPoint(x: cx - 17, y: 262), control: CGPoint(x: cx, y: 250))
            ctx.paint(beard, suit == 0 ? rgb(0.85, 0.85, 0.85) : hair, line: 1.4)
        }
        let stache = CGMutablePath()
        stache.move(to: CGPoint(x: cx - 12, y: 254))
        stache.addQuadCurve(to: CGPoint(x: cx, y: 258), control: CGPoint(x: cx - 6, y: 260))
        stache.addQuadCurve(to: CGPoint(x: cx + 12, y: 254), control: CGPoint(x: cx + 6, y: 260))
        ctx.stroke(stache, ober && suit == 0 ? rgb(0.7, 0.7, 0.7) : hair, 3)
        ctx.fill(ellipse(cx - 7, 268, 4, 4), CardArt.ink)
        ctx.fill(ellipse(cx + 7, 268, 4, 4), CardArt.ink)
        ctx.stroke(polyline([(cx, 266), (cx - 2, 259)]), rgb(0.7, 0.45, 0.35), 1.4)

        if ober {
            let feather = CGMutablePath()
            feather.move(to: CGPoint(x: cx + 12, y: 296))
            feather.addCurve(to: CGPoint(x: cx + 26, y: 334), control1: CGPoint(x: cx + 30, y: 304), control2: CGPoint(x: cx + 34, y: 322))
            ctx.stroke(feather, CardArt.ink, 7)
            ctx.stroke(feather, rgb(0.98, 0.98, 0.98), 4.5)
            ctx.paint(roundRect(cx - 16, 282, 32, 22, 5), coat, line: 1.6)
            ctx.paint(ellipse(cx, 283, 64, 11), coat, line: 1.6)
            ctx.stroke(polyline([(cx - 16, 288), (cx + 16, 288)]), CardArt.gold, 3)
        } else {
            let cap = CGMutablePath()
            cap.move(to: CGPoint(x: cx - 22, y: 278))
            cap.addCurve(to: CGPoint(x: cx + 26, y: 284), control1: CGPoint(x: cx - 20, y: 302), control2: CGPoint(x: cx + 24, y: 304))
            cap.closeSubpath()
            ctx.paint(cap, breeches, line: 1.6)
            ctx.fill(ellipse(cx + 2, 300, 8, 8), CardArt.gold)
        }
    }

    /// A sleeve through the given points with a hand at the end.
    private static func arm(_ pts: [(CGFloat, CGFloat)], _ coat: CGColor, _ skin: CGColor, _ ctx: CGContext) {
        let p = polyline(pts)
        ctx.stroke(p, CardArt.ink, 17)
        ctx.stroke(p, coat, 13)
        let end = pts.last!
        ctx.paint(ellipse(end.0, end.1, 13, 13), skin, line: 1.4)
    }
}
