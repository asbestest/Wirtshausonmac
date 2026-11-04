import SwiftUI

let accent = Color(red: 0.13, green: 0.55, blue: 0.37)

/// Cached thumbnails for the pickers.
enum Thumbs {
    private struct Key: Hashable { let face: ItemFace, height: CGFloat }
    private static var cache: [Key: NSImage] = [:]
    static func clear() { cache = [:] }
    static func image(_ face: ItemFace, height: CGFloat) -> NSImage {
        let key = Key(face: face, height: height)
        if let i = cache[key] { return i }
        let i = CardArt.image(face, height: height)
        cache[key] = i
        return i
    }
}

/// A face drawn for a moment in time (for the animated preview).
struct LiveFace: View {
    let face: ItemFace
    let height: CGFloat

    var body: some View {
        if case .prop = face {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                Image(nsImage: NSImage(size: NSSize(width: height * CardArt.aspect(face), height: height), flipped: false) { r in
                    guard let cg = NSGraphicsContext.current?.cgContext else { return false }
                    CardArt.draw(face, at: t, in: cg, rect: r)
                    return true
                })
            }
        } else {
            Image(nsImage: Thumbs.image(face, height: height))
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: CardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if let item = store.active {
                HStack(alignment: .top, spacing: 20) {
                    LiveFace(face: item.face(store.deck), height: 170)
                        .shadow(color: .black.opacity(item.isCard ? 0.25 : 0), radius: 6, y: 3)
                        .onTapGesture { store.flip() }
                        .frame(width: 150, height: 170)
                    controls(item)
                }
            } else {
                Text(L("Nothing on screen – put down a card or something else below."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
            Divider()
            deckSection
            backSection
            Divider()
            propSection
            if store.items.count > 1 { itemList }
            Divider()
            footer
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 20)
        .frame(width: 600)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Wirtshaus covers my Mac").font(.title2.weight(.bold))
                Text(L("Playing cards and bits and pieces that float above everything – even browsers and full-screen apps."))
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func controls(_ item: ItemState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title(store.deck)).font(.headline)
                if item.isCard, item.faceUp, let nick = CardNames.nickname(store.deck, item.rank, item.suit) {
                    Text(nick).font(.callout.italic()).foregroundStyle(accent)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L("Size"))
                    Spacer()
                    Text("\(Int(item.height.rounded())) pt").monospacedDigit().foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait").font(.system(size: 8))
                    Slider(value: Binding(get: { CardSize.slider(forHeight: item.height) },
                                          set: { store.setHeight(CardSize.height(atSlider: $0)) }), in: 0...1)
                        .tint(accent)
                    Image(systemName: "rectangle.portrait").font(.system(size: 18))
                }
                .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L("Rotate"))
                    Spacer()
                    Text("\(Int(item.angle.rounded()))°").monospacedDigit().foregroundStyle(.secondary)
                    Button(L("Straight")) { store.setAngle(0) }
                        .controlSize(.small)
                        .disabled(item.angle == 0)
                }
                HStack(spacing: 8) {
                    Button { store.rotate(by: 15) } label: { Image(systemName: "rotate.left") }
                        .buttonStyle(.borderless).help(L("15° to the left"))
                    Slider(value: Binding(get: { item.angle }, set: { store.setAngle($0) }), in: -180...180)
                        .tint(accent)
                    Button { store.rotate(by: -15) } label: { Image(systemName: "rotate.right") }
                        .buttonStyle(.borderless).help(L("15° to the right"))
                }
                .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                if item.isCard {
                    Button(item.faceUp ? L("Show the back") : L("Show the front")) { store.flip() }
                }
                Button(L("Remove"), role: .destructive) { store.remove() }
            }
            Toggle(isOn: Binding(get: { store.locked }, set: { store.setLocked($0) })) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("Lock"))
                    Text(L("Nothing moves any more, all clicks go to the app below."))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    private var activeCard: ItemState? { store.active.flatMap { $0.isCard ? $0 : nil } }

    private var deckSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("Cards")).font(.headline)
                Spacer()
                Picker("", selection: Binding(get: { store.deck }, set: { store.setDeck($0) })) {
                    ForEach(Deck.allCases, id: \.self) { d in Text("\(d.title) · \(d.game)").tag(d) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 330)
            }
            HStack(alignment: .top, spacing: store.deck == .french ? 10 : 4) {
                ForEach(store.deck.ranks, id: \.self) { rank in
                    VStack(spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(0..<4, id: \.self) { suit in
                                let on = activeCard.map { $0.faceUp && $0.rank == rank && $0.suit == suit } ?? false
                                thumb(.card(store.deck, rank, suit), height: 64, selected: on) { store.pickCard(rank, suit) }
                                    .help(CardNames.full(store.deck, rank, suit))
                            }
                        }
                        Text(rank == .sau ? L("Sows") : rank == .ace ? L("Aces") : rank == .jack ? L("Jacks") : rank.title)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Text(activeCard == nil ? L("A click puts the card down.") : L("A click shows the card on the selected card. Jack ↔ Ober and Ace ↔ Sow swap when you switch decks."))
                .font(.caption).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var backSection: some View {
        HStack(spacing: 8) {
            Text(L("Back")).font(.headline).frame(width: 90, alignment: .leading)
            ForEach(CardBack.allCases, id: \.self) { b in
                let on = activeCard.map { !$0.faceUp && $0.back == b } ?? false
                thumb(.back(store.deck, b), height: 52, selected: on) { store.pickBack(b) }
                    .help(b.title)
            }
            Spacer()
            if store.items.filter(\.isCard).count > 1, let c = activeCard {
                Button(L("For all cards")) { store.setBackForAll(c.back) }.controlSize(.small)
            }
        }
    }

    private var propSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Add")).font(.headline)
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(Prop.allCases, id: \.self) { p in
                    Button { store.addProp(p) } label: {
                        VStack(spacing: 4) {
                            Image(nsImage: Thumbs.image(.prop(p), height: 76))
                            Text(p.title).font(.caption)
                            Text(p.animation).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(minWidth: 90)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var itemList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("On screen")).font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.items) { i in
                        thumb(i.face(store.deck), height: 44, selected: i.id == store.activeID) { store.select(i.id) }
                            .help(i.title(store.deck))
                    }
                }
                .padding(2)
            }
        }
    }

    private func thumb(_ face: ItemFace, height: CGFloat, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(nsImage: Thumbs.image(face, height: height))
                .overlay(
                    RoundedRectangle(cornerRadius: height * 0.07, style: .continuous)
                        .strokeBorder(selected ? accent : .clear, lineWidth: 2.5)
                        .padding(-3)
                )
                .padding(3)
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle(L("Start at login"), isOn: Binding(get: { store.launchAtLogin },
                                                              set: { store.setLaunchAtLogin($0) }))
                    .toggleStyle(.switch).controlSize(.small)
                if let e = store.loginError { Text(e).font(.caption).foregroundStyle(.red) }
                Spacer()
                Button(L("Remove everything")) { store.removeAll() }.disabled(store.items.isEmpty)
            }
            let hk = HotKeys.modifierSymbols
            Text(String(format: L("Drag = move · double-click = flip · right-click = menu · scroll = size · ⌥ + scroll or two-finger turn = rotate · %@K on/off · %@L lock"), hk, hk))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
