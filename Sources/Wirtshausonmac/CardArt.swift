import AppKit
import CoreText

/// Draws cards and things with Core Graphics, so they stay sharp at any size.
/// Each face is laid out on its own grid (y up, 350 units high) and scaled to the target rect.
enum CardArt {
    static let H: CGFloat = 350
    static let corner: CGFloat = 16

    static let paper = CGColor(red: 1, green: 0.995, blue: 0.98, alpha: 1)
    static let edge = CGColor(red: 0.78, green: 0.78, blue: 0.76, alpha: 1)
    static let ink = CGColor(red: 0.16, green: 0.11, blue: 0.08, alpha: 1)
    private static let red = CGColor(red: 0.78, green: 0.06, blue: 0.16, alpha: 1)
    private static let black = CGColor(red: 0.1, green: 0.1, blue: 0.11, alpha: 1)
    private static let cream = CGColor(red: 0.96, green: 0.92, blue: 0.82, alpha: 1)
    static let gold = CGColor(red: 0.84, green: 0.65, blue: 0.22, alpha: 1)

    /// Grid width of a face (height is always 350). French cards are 63 × 88 mm; Bavarian ones are
    /// narrower and take the shape of their pictures.
    static func width(_ face: ItemFace) -> CGFloat {
        switch face {
        case .card(let d, _, _), .back(let d, _): d == .french ? 250 : BavarianArt.width
        case .prop(let p): PropArt.width(p)
        }
    }

    static func aspect(_ face: ItemFace) -> CGFloat { width(face) / H }

    /// Animated faces are drawn for the moment `t` (seconds).
    static func draw(_ face: ItemFace, at t: Double = 1.5, in ctx: CGContext, rect: CGRect) {
        let w = width(face)
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.minY)
        ctx.scaleBy(x: rect.width / w, y: rect.height / H)
        ctx.textMatrix = .identity
        switch face {
        case .card(.french, let rank, let suit): drawFrench(rank: rank, suit: Suit.french(suit), w: w, ctx)
        case .card(_, let rank, let suit): BavarianArt.draw(rank: rank, suit: suit, w: w, ctx)
        case .back(let deck, let back): drawBack(back, deck: deck, w: w, ctx)
        case .prop(let p): PropArt.draw(p, t: t, ctx)
        }
        ctx.restoreGState()
    }

    static func image(_ face: ItemFace, height: CGFloat) -> NSImage {
        let size = NSSize(width: (height * aspect(face)).rounded(), height: height)
        return NSImage(size: size, flipped: false) { r in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(face, in: ctx, rect: r)
            return true
        }
    }

    static func outline(w: CGFloat, radius: CGFloat = corner) -> CGPath {
        CGPath(roundedRect: CGRect(x: 0.75, y: 0.75, width: w - 1.5, height: H - 1.5),
               cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    static func blankCard(w: CGFloat, radius: CGFloat = corner, _ ctx: CGContext) {
        ctx.addPath(outline(w: w, radius: radius))
        ctx.setFillColor(paper)
        ctx.fillPath()
        ctx.addPath(outline(w: w, radius: radius))
        ctx.setStrokeColor(edge)
        ctx.setLineWidth(1.5)
        ctx.strokePath()
    }

    // MARK: French (Skat: Buben and Asse)

    private static func drawFrench(rank: Rank, suit: Suit, w: CGFloat, _ ctx: CGContext) {
        blankCard(w: w, ctx)
        let ink = suit.isRed ? red : black
        mirrored(w: w, ctx) { drawIndex(rank: rank, suit: suit, ink: ink, ctx) }
        if rank == .ace {
            pip(suit, at: CGPoint(x: w / 2, y: H / 2), size: suit == .spades ? 124 : 100, ink: ink, ctx)
        } else {
            drawJack(suit: suit, ink: ink, w: w, ctx)
        }
    }

    /// Draws `body` once upright and once turned around the card's middle, like the corners of a real card.
    static func mirrored(w: CGFloat, _ ctx: CGContext, _ body: () -> Void) {
        body()
        ctx.saveGState()
        ctx.translateBy(x: w, y: H)
        ctx.rotate(by: .pi)
        body()
        ctx.restoreGState()
    }

    private static func drawIndex(rank: Rank, suit: Suit, ink: CGColor, _ ctx: CGContext) {
        text(rank == .ace ? "A" : "J", size: 46, color: ink, centerX: 25, top: H - 14, ctx)
        pip(suit, at: CGPoint(x: 25, y: H - 76), size: 26, ink: ink, ctx)
    }

    /// A framed, double-headed picture with letter, feathered cap and pip.
    private static func drawJack(suit: Suit, ink: CGColor, w: CGFloat, _ ctx: CGContext) {
        let frame = CGRect(x: 52, y: 40, width: 146, height: 270)
        let framePath = CGPath(roundedRect: frame, cornerWidth: 6, cornerHeight: 6, transform: nil)
        ctx.addPath(framePath)
        ctx.setFillColor(cream)
        ctx.fillPath()

        ctx.saveGState()
        ctx.addPath(framePath)
        ctx.clip()
        mirrored(w: w, ctx) {
            ctx.setFillColor(ink.copy(alpha: 0.08)!)
            ctx.fill(CGRect(x: 52, y: 175, width: 146, height: 40))
            cap(centerX: 140, base: 262, ink: ink, ctx)
            text("J", size: 104, color: ink, centerX: 140, top: 254, ctx)
            pip(suit, at: CGPoint(x: 82, y: 278), size: 34, ink: ink, ctx)
            pip(suit, at: CGPoint(x: 78, y: 212), size: 22, ink: ink, ctx)
        }
        ctx.restoreGState()

        ctx.setStrokeColor(ink)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: 52, y: H / 2))
        ctx.addLine(to: CGPoint(x: 198, y: H / 2))
        ctx.strokePath()

        ctx.addPath(framePath)
        ctx.setLineWidth(2.2)
        ctx.strokePath()
        ctx.addPath(CGPath(roundedRect: frame.insetBy(dx: 5, dy: 5), cornerWidth: 3, cornerHeight: 3, transform: nil))
        ctx.setStrokeColor(gold)
        ctx.setLineWidth(1.2)
        ctx.strokePath()
    }

    private static func cap(centerX x: CGFloat, base y: CGFloat, ink: CGColor, _ ctx: CGContext) {
        let w: CGFloat = 64, h: CGFloat = 30
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x - w / 2, y: y))
        p.addQuadCurve(to: CGPoint(x: x + w / 2, y: y), control: CGPoint(x: x, y: y + h * 1.6))
        p.closeSubpath()
        ctx.addPath(p)
        ctx.setFillColor(gold)
        ctx.fillPath()
        ctx.addPath(p)
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(1.6)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.move(to: CGPoint(x: x + 6, y: y + h * 0.7))
        ctx.addQuadCurve(to: CGPoint(x: x + w / 2 + 8, y: y + h + 4), control: CGPoint(x: x + 30, y: y + h * 0.7))
        ctx.setLineWidth(2.4)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }

    // MARK: Back

    private static func backColors(_ b: CardBack) -> (base: CGColor, line: CGColor) {
        switch b {
        case .red: (CGColor(red: 0.70, green: 0.12, blue: 0.16, alpha: 1), CGColor(red: 1, green: 0.78, blue: 0.76, alpha: 1))
        case .blue: (CGColor(red: 0.12, green: 0.30, blue: 0.62, alpha: 1), CGColor(red: 0.74, green: 0.83, blue: 1, alpha: 1))
        case .green: (CGColor(red: 0.10, green: 0.42, blue: 0.27, alpha: 1), CGColor(red: 0.70, green: 0.92, blue: 0.78, alpha: 1))
        case .noir: (CGColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1), CGColor(red: 0.84, green: 0.68, blue: 0.32, alpha: 1))
        case .gray: (CGColor(red: 0.36, green: 0.38, blue: 0.41, alpha: 1), CGColor(red: 0.78, green: 0.80, blue: 0.83, alpha: 1))
        }
    }

    private static func drawBack(_ back: CardBack, deck: Deck, w: CGFloat, _ ctx: CGContext) {
        let (base, line) = backColors(back)
        blankCard(w: w, ctx)

        let inner = CGPath(roundedRect: CGRect(x: 11, y: 11, width: w - 22, height: H - 22),
                           cornerWidth: 9, cornerHeight: 9, transform: nil)
        ctx.addPath(inner)
        ctx.setFillColor(base)
        ctx.fillPath()

        // diagonal lattice
        ctx.saveGState()
        ctx.addPath(inner)
        ctx.clip()
        ctx.setStrokeColor(line.copy(alpha: 0.45)!)
        ctx.setLineWidth(1.6)
        var i: CGFloat = -H
        while i < w + H {
            ctx.move(to: CGPoint(x: i, y: 0)); ctx.addLine(to: CGPoint(x: i + H, y: H))
            ctx.move(to: CGPoint(x: i, y: H)); ctx.addLine(to: CGPoint(x: i + H, y: 0))
            i += 17
        }
        ctx.strokePath()
        ctx.restoreGState()

        ctx.addPath(CGPath(roundedRect: CGRect(x: 19, y: 19, width: w - 38, height: H - 38),
                           cornerWidth: 6, cornerHeight: 6, transform: nil))
        ctx.setStrokeColor(line)
        ctx.setLineWidth(1.8)
        ctx.strokePath()

        // medallion with the four suits
        let medal = CGRect(x: w / 2 - 52, y: H / 2 - 70, width: 104, height: 140)
        ctx.setFillColor(base)
        ctx.fillEllipse(in: medal)
        ctx.setStrokeColor(line)
        ctx.setLineWidth(3)
        ctx.strokeEllipse(in: medal)
        ctx.setLineWidth(1.2)
        ctx.strokeEllipse(in: medal.insetBy(dx: 7, dy: 7))
        let c = CGPoint(x: w / 2, y: H / 2)
        let spots: [(Int, CGFloat, CGFloat)] = [(1, 0, 34), (2, 26, 0), (0, 0, -34), (3, -26, 0)]
        for (s, dx, dy) in spots {
            let at = CGPoint(x: c.x + dx, y: c.y + dy)
            if deck == .bavarian {
                BavarianArt.pip(s, at: at, size: 30, ctx)
            } else {
                pip(Suit.french(s), at: at, size: 26, ink: line, ctx)
            }
        }
    }

    // MARK: Pieces

    static func pip(_ suit: Suit, at p: CGPoint, size: CGFloat, ink: CGColor, flipped: Bool = false, _ ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)
        ctx.scaleBy(x: size, y: size)
        if flipped { ctx.rotate(by: .pi) }
        ctx.addPath(suitPath(suit))
        ctx.setFillColor(ink)
        ctx.fillPath()
        ctx.restoreGState()
    }

    /// The suit shapes, centered on the origin and filling −0.5…0.5.
    static func suitPath(_ suit: Suit) -> CGPath {
        let p = CGMutablePath()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        func stem() {
            p.move(to: pt(0, -0.16))
            p.addCurve(to: pt(-0.21, -0.5), control1: pt(0, -0.38), control2: pt(-0.1, -0.48))
            p.addLine(to: pt(0.21, -0.5))
            p.addCurve(to: pt(0, -0.16), control1: pt(0.1, -0.48), control2: pt(0, -0.38))
            p.closeSubpath()
        }
        switch suit {
        case .hearts:
            p.move(to: pt(0, -0.48))
            p.addCurve(to: pt(-0.5, 0.12), control1: pt(-0.14, -0.3), control2: pt(-0.5, -0.1))
            p.addCurve(to: pt(0, 0.3), control1: pt(-0.5, 0.5), control2: pt(-0.06, 0.54))
            p.addCurve(to: pt(0.5, 0.12), control1: pt(0.06, 0.54), control2: pt(0.5, 0.5))
            p.addCurve(to: pt(0, -0.48), control1: pt(0.5, -0.1), control2: pt(0.14, -0.3))
            p.closeSubpath()
        case .spades:
            p.move(to: pt(0, 0.5))
            p.addCurve(to: pt(-0.48, -0.06), control1: pt(-0.14, 0.32), control2: pt(-0.48, 0.16))
            p.addCurve(to: pt(0, -0.2), control1: pt(-0.48, -0.4), control2: pt(-0.08, -0.42))
            p.addCurve(to: pt(0.48, -0.06), control1: pt(0.08, -0.42), control2: pt(0.48, -0.4))
            p.addCurve(to: pt(0, 0.5), control1: pt(0.48, 0.16), control2: pt(0.14, 0.32))
            p.closeSubpath()
            stem()
        case .clubs:
            let r: CGFloat = 0.21
            for c in [pt(0, 0.27), pt(-0.26, -0.07), pt(0.26, -0.07)] {
                p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            }
            p.addEllipse(in: CGRect(x: -0.14, y: -0.1, width: 0.28, height: 0.28))
            stem()
        case .diamonds:
            p.move(to: pt(0, 0.5))
            p.addQuadCurve(to: pt(0.38, 0), control: pt(0.15, 0.2))
            p.addQuadCurve(to: pt(0, -0.5), control: pt(0.15, -0.2))
            p.addQuadCurve(to: pt(-0.38, 0), control: pt(-0.15, -0.2))
            p.addQuadCurve(to: pt(0, 0.5), control: pt(-0.15, 0.2))
            p.closeSubpath()
        }
        return p
    }

    private static func serifBold(_ size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: .bold)
        if let d = base.fontDescriptor.withDesign(.serif), let f = NSFont(descriptor: d, size: size) { return f }
        return base
    }

    /// Draws `s` horizontally centered on `centerX` with its glyphs' top edge at `top`.
    private static func text(_ s: String, size: CGFloat, kern: CGFloat = 0, color: CGColor,
                             centerX: CGFloat, top: CGFloat, _ ctx: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: serifBold(size),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            .kern: kern,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attrs))
        let b = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        ctx.textPosition = CGPoint(x: centerX - b.midX, y: top - b.maxY)
        CTLineDraw(line, ctx)
    }
}

/// Small drawing helpers shared by the Bavarian cards and the props.
extension CGContext {
    func fill(_ path: CGPath, _ color: CGColor) {
        addPath(path); setFillColor(color); fillPath()
    }

    func stroke(_ path: CGPath, _ color: CGColor, _ width: CGFloat) {
        addPath(path); setStrokeColor(color); setLineWidth(width)
        setLineJoin(.round); setLineCap(.round); strokePath()
    }

    /// Fills and outlines a path.
    func paint(_ path: CGPath, _ color: CGColor, line: CGFloat = 2, ink: CGColor = CardArt.ink) {
        fill(path, color)
        stroke(path, ink, line)
    }

    /// Fills `path` with a vertical gradient (top colour first).
    func gradient(_ path: CGPath, _ top: CGColor, _ bottom: CGColor) {
        saveGState()
        addPath(path)
        clip()
        let b = path.boundingBox
        let g = CGGradient(colorsSpace: nil, colors: [top, bottom] as CFArray, locations: [0, 1])!
        drawLinearGradient(g, start: CGPoint(x: b.midX, y: b.maxY), end: CGPoint(x: b.midX, y: b.minY), options: [])
        restoreGState()
    }
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h), transform: nil)
}

func roundRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: min(r, w / 2), cornerHeight: min(r, h / 2), transform: nil)
}

func polyline(_ pts: [(CGFloat, CGFloat)], closed: Bool = false) -> CGPath {
    let p = CGMutablePath()
    p.addLines(between: pts.map { CGPoint(x: $0.0, y: $0.1) })
    if closed { p.closeSubpath() }
    return p
}
