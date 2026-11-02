import AppKit

/// A borderless panel that floats over every app, fullscreen ones included, without ever
/// activating the app: clicking or dragging an item leaves the app below in front (and in fullscreen).
final class CardPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class CardView: NSView {
    var face: ItemFace = .back(.french, .red) {
        didSet { if face != oldValue { needsDisplay = true; updateTimer() } }
    }

    var onGrab: (() -> Void)?
    var onDrag: ((CGPoint) -> Void)?          // total mouse offset since the grab, screen points
    var onRelease: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?
    var onResize: ((CGFloat) -> Void)?        // factor
    var onRotate: ((CGFloat) -> Void)?        // degrees, counter-clockwise

    /// The item's own size and turn; the view is its bounding box.
    var itemSize = CGSize(width: 100, height: 140)
    var angle: CGFloat = 0

    private var grabMouse: CGPoint?
    private var timer: Timer?
    private let start = CACurrentMediaTime() - Double.random(in: 0...20)   // props don't move in sync

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Moved to a screen with a different resolution: render again at its scale.
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsDisplay = true
    }

    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var isAnimated: Bool { if case .prop = face { true } else { false } }

    /// Everything skips AppKit's drawing and backing store: the face is rendered into a bitmap and handed
    /// to the layer (cards once per change, props every frame), so each item keeps a single buffer.
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        guard let layer else { return }
        guard isAnimated else { return renderCard(into: layer) }
        // big props render at most ~1100 px across: smoke and foam stay smooth, memory stays small
        let longest = max(bounds.width, bounds.height, 1)
        let scale = min(window?.backingScaleFactor ?? 2, 1100 / longest)
        let w = Int((bounds.width * scale).rounded()), h = Int((bounds.height * scale).rounded())
        guard w > 0, h > 0 else { return }
        // the screen's own colour space and pixel layout, so nothing gets converted per frame
        let space = window?.screen?.colorSpace?.cgColorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        if frameContext?.width != w || frameContext?.height != h || frameContext?.colorSpace != space {
            frameContext = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        }
        guard let ctx = frameContext, case .prop(let prop) = face else { return }
        let layers = PropArt.layers(prop)
        // the item itself, unturned, in pixels
        let iw = Int((itemSize.width * scale).rounded()), ih = Int((itemSize.height * scale).rounded())
        guard iw > 0, ih > 0 else { return }
        let item = CGRect(x: -CGFloat(iw) / 2, y: -CGFloat(ih) / 2, width: CGFloat(iw), height: CGFloat(ih))

        // the still layers are rendered once per size and reused
        let key = StillKey(face: face, width: iw, height: ih)
        if stillKey != key {
            stillKey = key
            stills = [:]
            for (i, live) in layers.enumerated() where !live {
                guard let c = CGContext(data: nil, width: iw, height: ih, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                        bitmapInfo: ctx.bitmapInfo.rawValue) else { continue }
                c.scaleBy(x: CGFloat(iw) / PropArt.width(prop), y: CGFloat(ih) / CardArt.H)
                PropArt.draw(prop, layer: i, t: 0, c)
                stills[i] = c.makeImage()
            }
        }

        let t = CACurrentMediaTime() - start
        ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.saveGState()
        ctx.translateBy(x: CGFloat(w) / 2, y: CGFloat(h) / 2)
        ctx.rotate(by: angle * .pi / 180)
        for (i, live) in layers.enumerated() {
            if live {
                ctx.saveGState()
                ctx.translateBy(x: item.minX, y: item.minY)
                ctx.scaleBy(x: CGFloat(iw) / PropArt.width(prop), y: CGFloat(ih) / CardArt.H)
                PropArt.draw(prop, layer: i, t: t, ctx)
                ctx.restoreGState()
            } else if let img = stills[i] {
                ctx.draw(img, in: item)
            }
        }
        ctx.restoreGState()
        layer.contentsGravity = .resize
        layer.contents = ctx.makeImage()
    }

    /// A card is drawn once into a throwaway context; only the finished image stays.
    private func renderCard(into layer: CALayer) {
        let scale = window?.backingScaleFactor ?? 2
        let w = Int((bounds.width * scale).rounded()), h = Int((bounds.height * scale).rounded())
        guard w > 0, h > 0 else { return }
        let space = window?.screen?.colorSpace?.cgColorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return }
        frameContext = nil
        stills = [:]
        stillKey = nil
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: bounds.midX, y: bounds.midY)
        ctx.rotate(by: angle * .pi / 180)
        let r = CGRect(x: -itemSize.width / 2, y: -itemSize.height / 2, width: itemSize.width, height: itemSize.height)
        CardArt.draw(face, in: ctx, rect: r)
        layer.contentsGravity = .resize
        layer.contents = ctx.makeImage()
    }

    private struct StillKey: Equatable { let face: ItemFace, width: Int, height: Int }
    private var frameContext: CGContext?
    private var stillKey: StillKey?
    private var stills: [Int: CGImage] = [:]

    /// Props redraw 20 times a second while on screen (smoke and steam drift slowly).
    func updateTimer() {
        let run = isAnimated && window?.isVisible == true
        if run, timer == nil {
            let t = Timer(timeInterval: 1.0 / 20, repeats: true) { [weak self] _ in self?.needsDisplay = true }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        } else if !run {
            timer?.invalidate()
            timer = nil
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.translateBy(x: bounds.midX, y: bounds.midY)
        ctx.rotate(by: angle * .pi / 180)
        let r = CGRect(x: -itemSize.width / 2, y: -itemSize.height / 2, width: itemSize.width, height: itemSize.height)
        CardArt.draw(face, at: CACurrentMediaTime() - start, in: ctx, rect: r)
    }

    /// True on the item itself; the empty corners of a turned item, and smoke or steam, let clicks through.
    func isSolid(at p: NSPoint) -> Bool {
        // into the item's own, unturned coordinates (origin bottom left)
        let a = -angle * .pi / 180, dx = p.x - bounds.midX, dy = p.y - bounds.midY
        let q = CGPoint(x: dx * cos(a) - dy * sin(a) + itemSize.width / 2, y: dx * sin(a) + dy * cos(a) + itemSize.height / 2)
        guard case .prop(let prop) = face else { return CGRect(origin: .zero, size: itemSize).contains(q) }
        let s = PropArt.solid(prop), k = itemSize.height / CardArt.H
        return CGRect(x: s.minX * k, y: s.minY * k, width: s.width * k, height: s.height * k).contains(q)
    }

    override func mouseDown(with e: NSEvent) {
        if e.clickCount == 2 { onDoubleClick?(); return }
        grabMouse = NSEvent.mouseLocation
        NSCursor.closedHand.set()
        onGrab?()
    }

    override func mouseDragged(with e: NSEvent) {
        guard let start = grabMouse else { return }
        let m = NSEvent.mouseLocation
        onDrag?(CGPoint(x: m.x - start.x, y: m.y - start.y))
    }

    override func mouseUp(with e: NSEvent) {
        guard grabMouse != nil else { return }
        grabMouse = nil
        NSCursor.openHand.set()
        onRelease?()
    }

    override func rightMouseDown(with e: NSEvent) { onRightClick?(e) }

    /// Scrolling or pinching over an item resizes it; with ⌥ held, scrolling turns it.
    override func scrollWheel(with e: NSEvent) {
        let raw = abs(e.scrollingDeltaY) >= abs(e.scrollingDeltaX) ? e.scrollingDeltaY : e.scrollingDeltaX
        let d = e.hasPreciseScrollingDeltas ? raw : raw * 8
        guard d != 0 else { return }
        if e.modifierFlags.contains(.option) { onRotate?(d * 0.5) } else { onResize?(exp(d * 0.006)) }
    }

    override func magnify(with e: NSEvent) { onResize?(1 + e.magnification) }

    /// Two-finger turn on the trackpad.
    override func rotate(with e: NSEvent) { onRotate?(CGFloat(e.rotation)) }
}

/// The window of one item. It's exactly the item's size, so everything around it stays clickable.
final class CardWindow {
    let panel: CardPanel
    let view: CardView
    private var hovering = false

    init() {
        panel = CardPanel(contentRect: NSRect(x: 0, y: 0, width: 100, height: 140),
                          styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        // all Spaces, and allowed into other apps' fullscreen Spaces
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.animationBehavior = .none
        view = CardView(frame: panel.contentRect(forFrameRect: panel.frame))
        view.autoresizingMask = [.width, .height]
        panel.contentView = view
    }

    static func size(of item: ItemState, deck: Deck) -> CGSize {
        CGSize(width: item.height * CardArt.aspect(item.face(deck)), height: item.height)
    }

    /// The bounding box of the turned item.
    static func frame(for item: ItemState, deck: Deck) -> NSRect {
        let s = size(of: item, deck: deck), a = item.angle * .pi / 180
        let w = abs(s.width * cos(a)) + abs(s.height * sin(a)), h = abs(s.width * sin(a)) + abs(s.height * cos(a))
        return NSRect(x: item.centerX - w / 2, y: item.centerY - h / 2, width: w, height: h)
    }

    func apply(_ item: ItemState, deck: Deck) {
        view.face = item.face(deck)
        let size = CardWindow.size(of: item, deck: deck), angle = CGFloat(item.angle)
        if size != view.itemSize || angle != view.angle {
            view.itemSize = size
            view.angle = angle
            view.needsDisplay = true
            turned = true
        }
        // cards get the system shadow in their shape; props draw their own (it would follow the smoke)
        panel.hasShadow = item.isCard
        setFrame(CardWindow.frame(for: item, deck: deck))
        updateMouse()
    }

    func setFrame(_ frame: NSRect) {
        guard frame != panel.frame || turned else { return }
        let reshaped = frame.size != panel.frame.size || turned
        turned = false
        panel.setFrame(frame, display: true)
        if reshaped {
            view.display()
            if panel.hasShadow { panel.invalidateShadow() }
        }
    }

    /// Set when size or angle changed, so the next frame update redraws even if the box stays the same.
    private var turned = false

    func show() { panel.orderFrontRegardless(); view.updateTimer() }
    func hide() { panel.orderOut(nil); view.updateTimer() }

    var locked = false { didSet { updateMouse() } }

    /// Called as the pointer moves: the window only takes clicks over the solid part of the item.
    func pointerMoved(to screenPoint: NSPoint) {
        let p = view.convert(panel.convertPoint(fromScreen: screenPoint), from: nil)
        let over = view.isSolid(at: p)
        if over != hovering {
            hovering = over
            updateMouse()
            if over && !locked { NSCursor.openHand.set() } else if !over { NSCursor.arrow.set() }
        }
    }

    private func updateMouse() {
        let ignore = locked || ((view.isAnimated || view.angle != 0) && !hovering)
        if panel.ignoresMouseEvents != ignore { panel.ignoresMouseEvents = ignore }
    }
}
