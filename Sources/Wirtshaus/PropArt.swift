import CoreGraphics
import Foundation

/// Animated things: a Maß that foams, a cigarette that smokes, a steaming Bratwurstsemmel and coffee,
/// and a Brezn with a glint. Drawn for a moment `t` (seconds) on a grid 350 units high.
///
/// Each prop is painted in layers, back to front. Still layers never change, so the window renders
/// them once and only redraws the live ones (smoke, steam, bubbles, foam, glow) every frame.
enum PropArt {
    static func width(_ p: Prop) -> CGFloat {
        switch p {
        case .beer: 250
        case .cigarette: 260
        case .bratwurst: 330
        case .coffee: 260
        case .pretzel: 360
        }
    }

    /// The part that catches clicks; smoke and steam above it let them through.
    static func solid(_ p: Prop) -> CGRect {
        switch p {
        case .beer: CGRect(x: 0, y: 0, width: 250, height: 275)
        case .cigarette: CGRect(x: 10, y: 10, width: 240, height: 70)
        case .bratwurst: CGRect(x: 0, y: 10, width: 330, height: 115)
        case .coffee: CGRect(x: 0, y: 10, width: 260, height: 160)
        case .pretzel: CGRect(x: 0, y: 20, width: 360, height: 300)
        }
    }

    /// Per layer, back to front: true if it moves.
    static func layers(_ p: Prop) -> [Bool] {
        switch p {
        case .beer: [false, true, true]                 // mug, bubbles, foam
        case .cigarette: [true, false, true]             // smoke, cigarette, ember
        case .bratwurst, .coffee: [true, false]          // steam, food
        case .pretzel: [false, true]                     // Brezn, glint
        }
    }

    static func draw(_ p: Prop, t: Double, _ ctx: CGContext) {
        for layer in layers(p).indices { draw(p, layer: layer, t: t, ctx) }
    }

    static func draw(_ p: Prop, layer: Int, t: Double, _ ctx: CGContext) {
        let t = CGFloat(t)
        switch p {
        case .beer: beer(layer, t, ctx)
        case .cigarette: cigarette(layer, t, ctx)
        case .bratwurst: layer == 0 ? steam(xs: [105, 165, 225], from: 126, to: 335, t: t, ctx) : bratwurst(ctx)
        case .coffee: layer == 0 ? steam(xs: [108, 148], from: 168, to: 340, t: t, ctx) : coffee(ctx)
        case .pretzel: layer == 0 ? pretzel(ctx) : glint(t, ctx)
        }
    }

    /// Stable pseudo-random number in 0…1.
    private static func rnd(_ i: Int, _ k: Int) -> CGFloat {
        let v = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return CGFloat(v - floor(v))
    }

    private static func frac(_ x: CGFloat) -> CGFloat { x - floor(x) }

    private static func shadow(_ cx: CGFloat, _ y: CGFloat, _ w: CGFloat, _ ctx: CGContext) {
        ctx.fill(ellipse(cx, y, w, 12), rgb(0, 0, 0, 0.16))
    }

    // MARK: Maß

    private static let beerRect = CGRect(x: 28, y: 30, width: 154, height: 186)
    private static let beerPath = roundRect(28, 30, 154, 186, 8)
    private static let glass = roundRect(20, 14, 170, 240, 16)

    private static func beer(_ layer: Int, _ t: CGFloat, _ ctx: CGContext) {
        let glassLine = rgb(0.55, 0.65, 0.7)
        switch layer {
        case 0:
            shadow(110, 14, 200, ctx)
            let handle = CGMutablePath()
            handle.move(to: CGPoint(x: 186, y: 215))
            handle.addCurve(to: CGPoint(x: 186, y: 70), control1: CGPoint(x: 260, y: 215), control2: CGPoint(x: 260, y: 70))
            ctx.stroke(handle, glassLine, 24)
            ctx.stroke(handle, rgb(0.9, 0.95, 0.97), 18)
            ctx.stroke(handle, rgb(1, 1, 1, 0.7), 4)
            ctx.fill(glass, rgb(0.9, 0.95, 0.97, 0.6))
            ctx.gradient(beerPath, rgb(1, 0.82, 0.3), rgb(0.86, 0.52, 0.08))
            // the Maßkrug's dimples, thick bottom, outline
            for row in 0..<5 {
                for col in 0..<5 {
                    let x = 46 + CGFloat(col) * 30 + (row.isMultiple(of: 2) ? 0 : 15)
                    guard x < 178 else { continue }
                    ctx.stroke(ellipse(x, 56 + CGFloat(row) * 36, 22, 28), rgb(1, 1, 1, 0.32), 2)
                }
            }
            ctx.fill(roundRect(20, 14, 170, 18, 8), rgb(0.85, 0.92, 0.95, 0.9))
            ctx.stroke(glass, glassLine, 3)
            ctx.fill(roundRect(32, 40, 8, 200, 4), rgb(1, 1, 1, 0.4))

        case 1:   // rising bubbles
            ctx.saveGState()
            ctx.addPath(beerPath)
            ctx.clip()
            ctx.setFillColor(rgb(1, 0.97, 0.85, 0.75))
            for i in 0..<26 {
                let phase = frac(t * (0.18 + rnd(i, 1) * 0.25) + rnd(i, 2))
                let x = beerRect.minX + 8 + rnd(i, 3) * (beerRect.width - 16) + sin(t * 3 + CGFloat(i)) * 2
                let y = beerRect.minY + phase * beerRect.height
                let r = 1.4 + rnd(i, 4) * 2.4
                ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
            }
            ctx.restoreGState()

        default:  // foam: a wobbling head that overhangs the rim, plus a drip running down
            let foam = CGMutablePath()
            foam.addRect(CGRect(x: 18, y: 208, width: 174, height: 38))
            for i in 0..<7 {
                let cx = 28 + CGFloat(i) * 25.5
                let r = 17 + 3 * sin(t * 1.7 + CGFloat(i) * 1.3)
                foam.addEllipse(in: CGRect(x: cx - r, y: 246 + 2 * sin(t * 2.1 + CGFloat(i)) - r, width: 2 * r, height: 2 * r))
            }
            let dripLen = 70 * min(1, frac(t / 7) * 1.4)
            foam.addPath(roundRect(14, 222 - dripLen, 12, dripLen + 10, 6))
            ctx.fill(foam, rgb(1, 0.98, 0.92))
            ctx.saveGState()
            ctx.addPath(foam)
            ctx.clip()
            ctx.fill(CGPath(rect: CGRect(x: 0, y: 200, width: 250, height: 14), transform: nil), rgb(0.95, 0.9, 0.75, 0.8))
            ctx.setStrokeColor(rgb(0.88, 0.82, 0.68))
            ctx.setLineWidth(1.2)
            for i in 0..<14 {
                let pop = frac(t * 0.35 + rnd(i, 5))
                let r = (2 + rnd(i, 6) * 3) * (pop < 0.85 ? 1 : 1 - (pop - 0.85) * 6)
                guard r > 0 else { continue }
                ctx.strokeEllipse(in: CGRect(x: 28 + rnd(i, 7) * 154 - r, y: 218 + rnd(i, 8) * 40 - r, width: 2 * r, height: 2 * r))
            }
            ctx.restoreGState()
        }
    }

    // MARK: Zigarette

    // made once: building gradients every frame is what costs
    private static let puff = CGGradient(colorsSpace: nil, colors: [rgb(0.78, 0.78, 0.82), rgb(0.78, 0.78, 0.82, 0)] as CFArray,
                                         locations: [0, 1])!
    private static let ember = CGGradient(colorsSpace: nil, colors: [rgb(1, 0.45, 0.1, 0.55), rgb(1, 0.3, 0, 0)] as CFArray,
                                          locations: [0, 1])!
    private static let cigAngle: CGFloat = 0.1
    private static let cigOrigin = CGPoint(x: 26, y: 34)

    private static func cigarette(_ layer: Int, _ t: CGFloat, _ ctx: CGContext) {
        let tip = CGPoint(x: cigOrigin.x + cos(cigAngle) * 192, y: cigOrigin.y + sin(cigAngle) * 192)
        switch layer {
        case 0:   // smoke, behind everything
            for i in 0..<28 {
                let phase = frac(t * 0.2 + CGFloat(i) / 28)
                let y = tip.y + 6 + phase * 290
                let x = tip.x - phase * 70 + sin(phase * 7 + t * 1.1 + rnd(i, 1) * 3) * (4 + phase * 30)
                let r = 5 + phase * 28
                ctx.setAlpha(0.36 * (1 - phase) * min(1, phase * 10))
                ctx.drawRadialGradient(puff, startCenter: CGPoint(x: x, y: y), startRadius: 0,
                                       endCenter: CGPoint(x: x, y: y), endRadius: r, options: [])
            }
            ctx.setAlpha(1)
            let stream = CGMutablePath()
            stream.move(to: CGPoint(x: tip.x, y: tip.y + 6))
            for s in 1...12 {
                stream.addLine(to: CGPoint(x: tip.x + sin(CGFloat(s) * 0.6 - t * 4) * CGFloat(s) * 0.5, y: tip.y + 6 + CGFloat(s) * 4))
            }
            ctx.stroke(stream, rgb(0.78, 0.78, 0.82, 0.5), 2)

        case 1:
            shadow(122, 26, 210, ctx)
            ctx.saveGState()
            ctx.translateBy(x: cigOrigin.x, y: cigOrigin.y)
            ctx.rotate(by: cigAngle)
            ctx.paint(roundRect(0, -10, 56, 20, 3), rgb(0.86, 0.56, 0.26), line: 1.4, ink: rgb(0.5, 0.3, 0.12))
            ctx.setFillColor(rgb(0.7, 0.4, 0.15))
            for i in 0..<16 {
                ctx.fillEllipse(in: CGRect(x: 4 + rnd(i, 9) * 46, y: -7 + rnd(i, 10) * 13, width: 2.4, height: 2.4))
            }
            ctx.paint(CGPath(rect: CGRect(x: 56, y: -10, width: 120, height: 20), transform: nil), rgb(0.98, 0.98, 0.97),
                      line: 1.4, ink: rgb(0.65, 0.65, 0.65))
            ctx.stroke(polyline([(58, -10), (58, 10)]), CardArt.gold, 2)
            ctx.paint(CGPath(rect: CGRect(x: 176, y: -10, width: 13, height: 20), transform: nil), rgb(0.55, 0.54, 0.52),
                      line: 1, ink: rgb(0.4, 0.4, 0.4))
            ctx.restoreGState()

        default:  // glowing ember
            let glow = 0.65 + 0.35 * sin(t * 2.3) * sin(t * 0.7 + 1)
            ctx.saveGState()
            ctx.translateBy(x: cigOrigin.x, y: cigOrigin.y)
            ctx.rotate(by: cigAngle)
            ctx.setAlpha(glow)
            ctx.drawRadialGradient(ember, startCenter: CGPoint(x: 191, y: 0), startRadius: 0,
                                   endCenter: CGPoint(x: 191, y: 0), endRadius: 18, options: [])
            ctx.setAlpha(1)
            ctx.fill(ellipse(190, 0, 7, 19), rgb(1, 0.35 + 0.25 * glow, 0.05))
            ctx.restoreGState()
        }
    }

    // MARK: Steam (Bratwurst, Kaffee)

    private static func steam(xs: [CGFloat], from y0: CGFloat, to y1: CGFloat, t: CGFloat, _ ctx: CGContext) {
        ctx.setLineCap(.round)
        for (k, x0) in xs.enumerated() {
            var prev: CGPoint?
            var y = y0
            while y <= y1 {
                let u = (y - y0) / (y1 - y0)
                let p = CGPoint(x: x0 + sin(y * 0.045 - t * 2.4 + CGFloat(k) * 2) * (5 + u * 16), y: y)
                if let prev {
                    let puff = 0.5 + 0.5 * sin(y * 0.05 - t * 3 + CGFloat(k) * 1.7)
                    ctx.move(to: prev)
                    ctx.addLine(to: p)
                    ctx.setStrokeColor(gray: 0.82, alpha: 0.55 * sin(.pi * u) * puff)
                    ctx.setLineWidth(9 - u * 4)
                    ctx.strokePath()
                }
                prev = p
                y += 8
            }
        }
    }

    // MARK: Bratwurstsemmel

    private static func bratwurst(_ ctx: CGContext) {
        shadow(165, 26, 290, ctx)
        let crust = rgb(0.55, 0.32, 0.12)
        ctx.paint(ellipse(165, 92, 266, 48), rgb(0.82, 0.58, 0.3), line: 1.8, ink: crust)   // top half, behind

        let wurst = roundRect(14, 72, 302, 42, 21)
        ctx.gradient(wurst, rgb(0.8, 0.45, 0.24), rgb(0.5, 0.22, 0.1))
        ctx.saveGState()
        ctx.addPath(wurst)
        ctx.clip()
        for i in 0..<9 {
            let x = 40 + CGFloat(i) * 30
            ctx.stroke(polyline([(x, 72), (x + 22, 114)]), rgb(0.3, 0.12, 0.04, 0.6), 4)
        }
        ctx.stroke(polyline([(30, 106), (300, 106)]), rgb(1, 0.85, 0.7, 0.35), 4)
        ctx.restoreGState()
        ctx.stroke(wurst, rgb(0.3, 0.12, 0.04), 2)

        var pts: [(CGFloat, CGFloat)] = []
        for i in 0...16 { pts.append((60 + CGFloat(i) * 13, i.isMultiple(of: 2) ? 100 : 110)) }
        ctx.stroke(polyline(pts), rgb(0.8, 0.6, 0.05), 6.5)
        ctx.stroke(polyline(pts), rgb(0.98, 0.8, 0.15), 4.5)

        // bottom half of the Semmel in front
        let bun = CGMutablePath()
        bun.move(to: CGPoint(x: 28, y: 86))
        bun.addCurve(to: CGPoint(x: 302, y: 86), control1: CGPoint(x: 40, y: 20), control2: CGPoint(x: 290, y: 20))
        bun.addQuadCurve(to: CGPoint(x: 28, y: 86), control: CGPoint(x: 165, y: 70))
        ctx.gradient(bun, rgb(0.92, 0.7, 0.4), rgb(0.7, 0.42, 0.18))
        ctx.stroke(bun, crust, 1.8)
        ctx.stroke(polyline([(60, 66), (90, 50)]), rgb(1, 0.9, 0.7, 0.6), 3)
    }

    // MARK: Kaffee

    private static func coffee(_ ctx: CGContext) {
        let line = rgb(0.6, 0.6, 0.62)
        shadow(130, 22, 230, ctx)
        ctx.paint(ellipse(130, 38, 236, 40), rgb(0.97, 0.97, 0.96), line: 2, ink: line)
        ctx.stroke(ellipse(130, 42, 150, 20), rgb(0.85, 0.85, 0.85), 1.5)

        ctx.stroke(ellipse(212, 110, 50, 58), line, 14)
        ctx.stroke(ellipse(212, 110, 50, 58), rgb(0.98, 0.98, 0.97), 10)
        let cup = CGMutablePath()
        cup.move(to: CGPoint(x: 50, y: 150))
        cup.addCurve(to: CGPoint(x: 100, y: 44), control1: CGPoint(x: 50, y: 90), control2: CGPoint(x: 70, y: 50))
        cup.addLine(to: CGPoint(x: 160, y: 44))
        cup.addCurve(to: CGPoint(x: 210, y: 150), control1: CGPoint(x: 190, y: 50), control2: CGPoint(x: 210, y: 90))
        cup.closeSubpath()
        ctx.gradient(cup, rgb(1, 1, 1), rgb(0.88, 0.88, 0.87))
        ctx.stroke(cup, line, 2)
        ctx.stroke(polyline([(66, 128), (78, 82)]), rgb(1, 1, 1, 0.9), 5)
        ctx.paint(ellipse(130, 150, 160, 24), rgb(0.98, 0.98, 0.97), line: 2, ink: line)
        ctx.fill(ellipse(130, 150, 146, 18), rgb(0.33, 0.19, 0.09))
        ctx.stroke(ellipse(130, 150, 120, 12), rgb(0.72, 0.5, 0.3, 0.8), 3)
    }

    // MARK: Brezn

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private static let belly: CGPath = {
        let b = CGMutablePath()
        b.move(to: p(318, 168))
        b.addCurve(to: p(180, 52), control1: p(316, 92), control2: p(252, 52))
        b.addCurve(to: p(42, 168), control1: p(108, 52), control2: p(44, 92))
        return b
    }()

    /// The two ends: up over the top, crossing down onto the belly.
    private static let arms: [CGPath] = {
        let right = CGMutablePath()
        right.move(to: p(318, 168))
        right.addCurve(to: p(220, 248), control1: p(320, 230), control2: p(268, 256))
        right.addCurve(to: p(134, 92), control1: p(174, 240), control2: p(134, 170))
        let left = CGMutablePath()
        left.move(to: p(42, 168))
        left.addCurve(to: p(140, 248), control1: p(40, 230), control2: p(92, 256))
        left.addCurve(to: p(226, 92), control1: p(186, 240), control2: p(226, 170))
        return [right, left]
    }()

    private static let dough: CGPath = {
        let shape = CGMutablePath()
        shape.addPath(belly.copy(strokingWithWidth: 52, lineCap: .round, lineJoin: .round, miterLimit: 1))
        for arm in arms { shape.addPath(arm.copy(strokingWithWidth: 34, lineCap: .round, lineJoin: .round, miterLimit: 1)) }
        return shape
    }()

    private static func pretzel(_ ctx: CGContext) {
        shadow(180, 30, 300, ctx)
        let dark = rgb(0.32, 0.15, 0.05), crust = rgb(0.6, 0.3, 0.09)
        ctx.stroke(belly, dark, 58)
        ctx.stroke(belly, crust, 52)
        ctx.stroke(belly, rgb(0.9, 0.68, 0.38), 16)   // the light split of the belly
        for arm in arms {
            ctx.stroke(arm, dark, 40)
            ctx.stroke(arm, crust, 34)
            ctx.stroke(arm, rgb(0.75, 0.45, 0.18), 10)
        }

        // coarse salt, scattered along the dough
        ctx.setFillColor(rgb(1, 1, 1, 0.95))
        let paths = [belly] + arms
        for i in 0..<34 {
            let path = paths[i % 3]
            let b = path.boundingBox
            let pt = p(b.minX + rnd(i, 11) * b.width, b.minY + rnd(i, 12) * b.height)
            guard path.copy(strokingWithWidth: 30, lineCap: .round, lineJoin: .round, miterLimit: 1).contains(pt) else { continue }
            ctx.saveGState()
            ctx.translateBy(x: pt.x, y: pt.y)
            ctx.rotate(by: rnd(i, 13) * 3)
            ctx.addPath(roundRect(-3, -2.5, 6, 5, 1.5))
            ctx.fillPath()
            ctx.restoreGState()
        }
    }

    private static let shine = CGGradient(colorsSpace: nil, colors: [rgb(1, 1, 1, 0), rgb(1, 0.95, 0.85, 0.45), rgb(1, 1, 1, 0)] as CFArray,
                                          locations: [0, 0.5, 1])!

    /// A glint sweeping across every few seconds.
    private static func glint(_ t: CGFloat, _ ctx: CGContext) {
        let x = 20 + (frac(t / 4) * 1.6 - 0.3) * 320
        guard x > -20, x < 380 else { return }
        ctx.saveGState()
        ctx.addPath(dough)
        ctx.clip(using: .winding)
        ctx.drawLinearGradient(shine, start: p(x - 30, 40), end: p(x + 30, 300), options: [])
        ctx.restoreGState()
    }
}
