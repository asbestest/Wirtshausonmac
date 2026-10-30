import AppKit
import ServiceManagement

/// All cards and things on screen, their windows and the shared switches.
/// "Active" is the item the menu and settings act on: the last one touched or added.
final class CardStore: ObservableObject {
    @Published private(set) var items: [ItemState] = []
    @Published private(set) var activeID: UUID?
    /// French (Skat) or Bavarian (Schafkopf). Applies to every card.
    @Published private(set) var deck: Deck
    @Published private(set) var visible: Bool
    /// Locked items let every click through to the app below and can't be moved.
    @Published private(set) var locked: Bool
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var loginError: String?

    var onOpenSettings: (() -> Void)?

    private var windows: [UUID: CardWindow] = [:]
    private var dragStart: CGPoint?
    private var monitors: [Any] = []
    private let defaults = UserDefaults.standard

    init() {
        CardStore.migrateFromCardonmac()
        defaults.register(defaults: ["visible": true, "locked": false, "deck": Deck.french.rawValue])
        visible = defaults.bool(forKey: "visible")
        locked = defaults.bool(forKey: "locked")
        deck = Deck(rawValue: defaults.integer(forKey: "deck")) ?? .french
        if let data = defaults.data(forKey: "items"),
           let saved = try? JSONDecoder().decode([ItemState].self, from: data) {
            for var item in saved {
                item.center = CardStore.onScreen(item.center)
                attach(item)
            }
        } else {
            // first launch: the top trump in the middle of the screen
            var first = ItemState()
            first.rank = deck == .french ? .jack : .ober
            add(first)
        }
        activeID = items.last?.id

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.keepOnScreen() }
        let moved: (NSEvent) -> Void = { [weak self] _ in self?.pointerMoved() }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler: moved) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved], handler: { moved($0); return $0 }) { monitors.append(m) }
    }

    /// The app was called Cardonmac before; take over its layout once.
    private static func migrateFromCardonmac() {
        let d = UserDefaults.standard
        guard d.object(forKey: "items") == nil, let old = UserDefaults(suiteName: "io.github.asbestest.cardonmac") else { return }
        for key in ["items", "deck", "visible", "locked", "didShowWelcome"] {
            if let v = old.object(forKey: key) { d.set(v, forKey: key) }
        }
    }

    var active: ItemState? { items.first { $0.id == activeID } }
    var hasCards: Bool { items.contains { $0.isCard } }

    // MARK: Adding and removing

    /// A random card from the current deck next to the active item.
    func addCard(rank: Rank? = nil, suit: Int? = nil, faceUp: Bool = true) {
        let pick = deck.cards.randomElement()!
        var c = ItemState()
        c.rank = rank ?? pick.rank
        c.suit = suit ?? pick.suit
        c.faceUp = faceUp
        if let a = items.last(where: \.isCard) { c.back = a.back }
        place(&c)
        add(c)
    }

    func addProp(_ p: Prop) {
        var item = ItemState()
        item.prop = p
        item.height = 160
        place(&item)
        add(item)
    }

    /// Next to the active item, at its size.
    private func place(_ item: inout ItemState) {
        guard let a = active else { return }
        if item.isCard == a.isCard { item.height = a.height }
        let step = max(14, a.height * 0.2)
        item.center = CardStore.onScreen(CGPoint(x: a.centerX + step, y: a.centerY - step))
    }

    private func add(_ item: ItemState) {
        var i = item
        if i.center == .zero, let s = NSScreen.main?.frame { i.center = CGPoint(x: s.midX, y: s.midY) }
        attach(i)
        activeID = i.id
        if !visible { setVisible(true) }
        save()
    }

    private func attach(_ item: ItemState) {
        let w = CardWindow()
        let id = item.id
        w.apply(item, deck: deck)
        w.locked = locked
        w.view.onGrab = { [unowned self] in
            self.activeID = id
            self.dragStart = self.item(id)?.center
            self.windows[id]?.panel.orderFrontRegardless()
        }
        w.view.onDrag = { [unowned self] d in
            guard let start = self.dragStart, var i = self.item(id) else { return }
            i.center = CGPoint(x: start.x + d.x, y: start.y + d.y)
            self.windows[id]?.setFrame(CardWindow.frame(for: i, deck: self.deck))   // just the window while dragging
        }
        w.view.onRelease = { [unowned self] in
            guard let f = self.windows[id]?.panel.frame else { return }
            self.dragStart = nil
            self.update(id) { $0.center = CardStore.onScreen(CGPoint(x: f.midX, y: f.midY)) }
        }
        w.view.onDoubleClick = { [unowned self] in self.activeID = id; self.flip(id) }
        w.view.onResize = { [unowned self] f in self.activeID = id; self.setHeight((self.item(id)?.height ?? 200) * f, of: id) }
        w.view.onRotate = { [unowned self] d in self.activeID = id; self.rotate(by: Double(d), of: id) }
        w.view.onRightClick = { [unowned self] e in
            self.activeID = id
            NSMenu.popUpContextMenu(self.contextMenu(for: id), with: e, for: w.view)
        }
        windows[id] = w
        items.append(item)
        if visible { w.show() }
    }

    func remove(_ id: UUID? = nil) {
        guard let id = id ?? activeID, let w = windows.removeValue(forKey: id) else { return }
        w.hide()
        items.removeAll { $0.id == id }
        if activeID == id { activeID = items.last?.id }
        save()
    }

    func removeAll() {
        for id in items.map(\.id) { remove(id) }
    }

    // MARK: Changing items

    private func item(_ id: UUID) -> ItemState? { items.first { $0.id == id } }

    private func update(_ id: UUID?, _ change: (inout ItemState) -> Void) {
        guard let id = id ?? activeID, let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
        windows[id]?.apply(items[i], deck: deck)
        save()
    }

    func setHeight(_ h: Double, of id: UUID? = nil) { update(id) { $0.height = CardSize.clamp(h) } }
    func setAngle(_ a: Double, of id: UUID? = nil) { update(id) { $0.angle = ItemState.normalized(a) } }

    /// Turning by small steps (gestures, scrolling) doesn't snap, or it would stick at straight angles.
    func rotate(by d: Double, of id: UUID? = nil) {
        update(id) {
            var a = ($0.angle + d).truncatingRemainder(dividingBy: 360)
            if a > 180 { a -= 360 } else if a < -180 { a += 360 }
            $0.angle = a
        }
    }

    func flip(_ id: UUID? = nil) {
        guard let i = id.flatMap(item) ?? active, i.isCard else { return }
        update(i.id) { $0.faceUp.toggle() }
    }

    /// Shows this card on the active card, or lays it out new if a prop is active.
    func pickCard(_ rank: Rank, _ suit: Int, for id: UUID? = nil) {
        guard let i = id.flatMap(item) ?? active, i.isCard else { return addCard(rank: rank, suit: suit) }
        update(i.id) { $0.rank = rank; $0.suit = suit; $0.faceUp = true }
    }

    func pickBack(_ b: CardBack, for id: UUID? = nil) {
        guard let i = id.flatMap(item) ?? active, i.isCard else {
            addCard(faceUp: false)
            return update(nil) { $0.back = b }
        }
        update(i.id) { $0.back = b; $0.faceUp = false }
    }

    /// The back colour for every card, so a "hiding" set looks the same.
    func setBackForAll(_ b: CardBack) { for i in items where i.isCard { update(i.id) { $0.back = b } } }

    func changeProp(_ p: Prop, of id: UUID) { update(id) { $0.prop = p } }

    /// Switches the deck; cards on screen become their counterpart (Bube ↔ Ober, Ass ↔ Sau).
    func setDeck(_ d: Deck) {
        guard d != deck else { return }
        deck = d
        defaults.set(d.rawValue, forKey: "deck")
        for i in items where i.isCard { update(i.id) { $0.rank = $0.rank.converted(to: d) } }
    }

    func select(_ id: UUID) {
        activeID = id
        windows[id]?.panel.orderFrontRegardless()
    }

    // MARK: Switches

    func setVisible(_ v: Bool) {
        visible = v
        // in list order, so later items stay on top
        for i in items { v ? windows[i.id]?.show() : windows[i.id]?.hide() }
        defaults.set(v, forKey: "visible")
    }

    func setLocked(_ l: Bool) {
        locked = l
        for w in windows.values { w.locked = l }
        defaults.set(l, forKey: "locked")
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Geht nur, wenn die App im Programme-Ordner liegt."
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func pointerMoved() {
        guard visible else { return }
        let m = NSEvent.mouseLocation
        for w in windows.values { w.pointerMoved(to: m) }
    }

    // MARK: Screens

    /// Pulls a center point back onto the nearest screen.
    private static func onScreen(_ p: CGPoint) -> CGPoint {
        let screens = NSScreen.screens.map(\.frame)
        if screens.contains(where: { $0.contains(p) }) { return p }
        guard let nearest = screens.min(by: { dist($0, p) < dist($1, p) }) else { return p }
        return CGPoint(x: min(max(p.x, nearest.minX + 4), nearest.maxX - 4),
                       y: min(max(p.y, nearest.minY + 4), nearest.maxY - 4))
    }

    private static func dist(_ r: CGRect, _ p: CGPoint) -> CGFloat {
        hypot(max(r.minX - p.x, 0, p.x - r.maxX), max(r.minY - p.y, 0, p.y - r.maxY))
    }

    private func keepOnScreen() {
        for i in items { update(i.id) { $0.center = CardStore.onScreen($0.center) } }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { defaults.set(data, forKey: "items") }
    }

    // MARK: Menus

    func contextMenu(for id: UUID) -> NSMenu {
        let menu = NSMenu()
        guard let item = item(id) else { return menu }
        if let prop = item.prop {
            addSliders(to: menu, id: id)
            let change = NSMenuItem(title: "Ändern zu", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for p in Prop.allCases {
                let i = ActionItem(p.title, on: p == prop) { [unowned self] in self.changeProp(p, of: id) }
                i.image = CardArt.image(.prop(p), height: 24)
                sub.addItem(i)
            }
            change.submenu = sub
            menu.addItem(change)
        } else {
            menu.addItem(ActionItem(item.faceUp ? "Umdrehen (Rückseite zeigen)" : "Umdrehen (Vorderseite zeigen)") { [unowned self] in self.flip(id) })
            menu.addItem(.separator())
            addSliders(to: menu, id: id)
            menu.addItem(cardsItem(selected: item.faceUp ? item : nil) { [unowned self] r, s in self.pickCard(r, s, for: id) })
            let backs = NSMenuItem(title: "Rückseite", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for b in CardBack.allCases {
                let i = ActionItem(b.title, on: !item.faceUp && item.back == b) { [unowned self] in self.pickBack(b, for: id) }
                i.image = CardArt.image(.back(deck, b), height: 22)
                sub.addItem(i)
            }
            backs.submenu = sub
            menu.addItem(backs)
            menu.addItem(deckItem())
        }
        menu.addItem(.separator())
        menu.addItem(ActionItem("Neue Karte") { [unowned self] in self.addCard() })
        menu.addItem(propsItem())
        menu.addItem(ActionItem("Fixieren – Klicks gehen durch") { [unowned self] in self.setLocked(true) })
        menu.addItem(ActionItem("Einstellungen …") { [unowned self] in self.onOpenSettings?() })
        menu.addItem(.separator())
        menu.addItem(ActionItem(item.isCard ? "Karte entfernen" : "\(item.prop!.title) entfernen") { [unowned self] in self.remove(id) })
        return menu
    }

    /// Size and turn sliders, plus "Gerade richten" when turned. `id` nil: the active item.
    func addSliders(to menu: NSMenu, id: UUID?) {
        menu.addItem(SliderItem(.size, store: self, id: id))
        menu.addItem(SliderItem(.angle, store: self, id: id))
        if let i = id.flatMap(item) ?? active, i.angle != 0 {
            menu.addItem(ActionItem("Gerade richten") { [unowned self] in self.setAngle(0, of: id) })
        }
        menu.addItem(.separator())
    }

    /// "Karte ▸" with the deck's cards, by rank.
    func cardsItem(selected: ItemState?, _ pick: @escaping (Rank, Int) -> Void) -> NSMenuItem {
        let parent = NSMenuItem(title: "Karte (\(deck.title))", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for rank in deck.ranks {
            if sub.numberOfItems > 0 { sub.addItem(.separator()) }
            for suit in 0..<4 {
                let on = selected.map { $0.rank == rank && $0.suit == suit } ?? false
                let i = ActionItem(CardNames.full(deck, rank, suit), on: on) { pick(rank, suit) }
                i.image = CardArt.image(.card(deck, rank, suit), height: 26)
                sub.addItem(i)
            }
        }
        parent.submenu = sub
        return parent
    }

    func deckItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Blatt", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for d in Deck.allCases {
            sub.addItem(ActionItem("\(d.title) (\(d.game))", on: d == deck) { [unowned self] in self.setDeck(d) })
        }
        parent.submenu = sub
        return parent
    }

    func propsItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Dazulegen", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for p in Prop.allCases {
            let i = ActionItem("\(p.title) (\(p.animation))") { [unowned self] in self.addProp(p) }
            i.image = CardArt.image(.prop(p), height: 24)
            sub.addItem(i)
        }
        parent.submenu = sub
        return parent
    }
}

/// Menu item that runs a closure.
final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", modifiers: NSEvent.ModifierFlags = .command,
         on: Bool = false, _ handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        keyEquivalentModifierMask = modifiers
        target = self
        state = on ? .on : .off
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func fire() { handler() }
}

/// "Größe" or "Drehen" with a live slider, for the menu bar menu and the right-click menu.
final class SliderItem: NSMenuItem {
    enum Kind { case size, angle }

    private let kind: Kind
    private let slider = NSSlider()
    private let valueLabel = NSTextField(labelWithString: "")
    private weak var store: CardStore?
    private let id: UUID?

    /// `id` nil: always acts on the active item.
    init(_ kind: Kind, store: CardStore, id: UUID?) {
        self.kind = kind
        self.store = store
        self.id = id
        super.init(title: "", action: nil, keyEquivalent: "")
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 46))
        let title = NSTextField(labelWithString: kind == .size ? "Größe" : "Drehen")
        title.font = .menuFont(ofSize: 0)
        title.textColor = .secondaryLabelColor
        title.frame = NSRect(x: 20, y: 25, width: 120, height: 16)
        valueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.frame = NSRect(x: 150, y: 25, width: 92, height: 16)
        slider.frame = NSRect(x: 18, y: 2, width: 226, height: 22)
        slider.minValue = kind == .size ? 0 : -180
        slider.maxValue = kind == .size ? 1 : 180
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(changed)
        [title, valueLabel, slider].forEach(v.addSubview)
        view = v
        refresh()
    }

    required init(coder: NSCoder) { fatalError() }

    func refresh() {
        guard let store, let c = id.flatMap({ id in store.items.first { $0.id == id } }) ?? store.active else {
            slider.isEnabled = false
            valueLabel.stringValue = ""
            return
        }
        slider.isEnabled = true
        switch kind {
        case .size:
            slider.doubleValue = CardSize.slider(forHeight: c.height)
            valueLabel.stringValue = "\(Int(c.height.rounded())) pt"
        case .angle:
            slider.doubleValue = c.angle
            valueLabel.stringValue = "\(Int(c.angle.rounded()))°"
        }
    }

    @objc private func changed() {
        switch kind {
        case .size: store?.setHeight(CardSize.height(atSlider: slider.doubleValue), of: id)
        case .angle: store?.setAngle(slider.doubleValue, of: id)
        }
        refresh()
    }
}
