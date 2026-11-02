import Foundation

/// Which deck the cards come from. Switching converts every card on screen.
enum Deck: Int, CaseIterable, Codable {
    case french, bavarian

    var title: String { ["Französisch", "Bayerisch"][rawValue] }
    var game: String { ["Skat", "Schafkopf"][rawValue] }

    /// Only the cards that matter: Buben and Asse for Skat, Ober, Unter and Säue for Schafkopf.
    var ranks: [Rank] { self == .french ? [.jack, .ace] : [.ober, .unter, .sau] }

    /// Suits in their game order (highest first): Kreuz/Pik/Herz/Karo and Eichel/Gras/Herz/Schellen.
    func suitTitle(_ s: Int) -> String {
        (self == .french ? ["Kreuz", "Pik", "Herz", "Karo"] : ["Eichel", "Gras", "Herz", "Schellen"])[s]
    }

    var cards: [(rank: Rank, suit: Int)] { ranks.flatMap { r in (0..<4).map { (r, $0) } } }
}

enum Rank: Int, Codable {
    case jack, ace, ober, unter, sau

    var title: String { ["Bube", "Ass", "Ober", "Unter", "Sau"][rawValue] }

    /// The card with the same role in the other deck (top trumps and aces swap places).
    func converted(to deck: Deck) -> Rank {
        switch (deck, self) {
        case (.french, .ober), (.french, .unter): .jack
        case (.french, .sau): .ace
        case (.bavarian, .jack): .ober
        case (.bavarian, .ace): .sau
        default: self
        }
    }
}

/// French suit glyphs, in deck order (Kreuz, Pik, Herz, Karo).
enum Suit: Int, CaseIterable {
    case spades, hearts, diamonds, clubs

    static func french(_ s: Int) -> Suit { [.clubs, .spades, .hearts, .diamonds][s] }
    var isRed: Bool { self == .hearts || self == .diamonds }
}

enum CardBack: Int, CaseIterable, Codable {
    case red, blue, green, noir, gray

    var title: String { ["Rot", "Blau", "Grün", "Schwarz-Gold", "Grau"][rawValue] }
}

/// Little animated things to put on screen besides cards.
enum Prop: Int, CaseIterable, Codable {
    case beer, cigarette, bratwurst, coffee, pretzel

    var title: String { ["Maß Bier", "Zigarette", "Bratwurst", "Kaffee", "Brezn"][rawValue] }
    var animation: String { ["schäumt", "raucht", "dampft", "dampft", "glänzt"][rawValue] }
}

enum ItemFace: Hashable {
    case card(Deck, Rank, Int)
    case back(Deck, CardBack)
    case prop(Prop)
}

/// One card or thing on screen. Positions are in global screen coordinates (points, y up).
struct ItemState: Codable, Identifiable, Equatable {
    var id = UUID()
    /// nil: a card.
    var prop: Prop?
    var rank = Rank.ace
    var suit = 0
    var back = CardBack.red
    var faceUp = true
    var height = 200.0
    var centerX = 0.0
    var centerY = 0.0
    /// Turn in degrees, counter-clockwise, −180…180.
    var angle = 0.0

    init() {}

    /// Fields added later (the angle) are optional, so older saved layouts still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        prop = try c.decodeIfPresent(Prop.self, forKey: .prop)
        rank = try c.decode(Rank.self, forKey: .rank)
        suit = try c.decode(Int.self, forKey: .suit)
        back = try c.decode(CardBack.self, forKey: .back)
        faceUp = try c.decode(Bool.self, forKey: .faceUp)
        height = try c.decode(Double.self, forKey: .height)
        centerX = try c.decode(Double.self, forKey: .centerX)
        centerY = try c.decode(Double.self, forKey: .centerY)
        angle = try c.decodeIfPresent(Double.self, forKey: .angle) ?? 0
    }

    var isCard: Bool { prop == nil }

    /// Keeps an angle in −180…180 and snaps it straight when it's within 2° of a right angle.
    static func normalized(_ a: Double) -> Double {
        var a = a.truncatingRemainder(dividingBy: 360)
        if a > 180 { a -= 360 } else if a < -180 { a += 360 }
        for straight in [-180.0, -90, 0, 90, 180] where abs(a - straight) < 2 { return straight }
        return a
    }

    func face(_ deck: Deck) -> ItemFace {
        if let prop { return .prop(prop) }
        return faceUp ? .card(deck, rank, suit) : .back(deck, back)
    }

    func title(_ deck: Deck) -> String {
        if let prop { return prop.title }
        return faceUp ? CardNames.name(deck, rank, suit) : "Rückseite \(back.title)"
    }

    var center: CGPoint {
        get { CGPoint(x: centerX, y: centerY) }
        set { centerX = newValue.x; centerY = newValue.y }
    }
}

enum CardNames {
    static func name(_ deck: Deck, _ rank: Rank, _ suit: Int) -> String {
        "\(deck.suitTitle(suit))-\(rank.title)"
    }

    /// What Schafkopf players call them.
    static func nickname(_ deck: Deck, _ rank: Rank, _ suit: Int) -> String? {
        guard deck == .bavarian else { return nil }
        switch (rank, suit) {
        case (.ober, 0): return "der Alte"
        case (.ober, 1): return "der Blaue"
        case (.ober, 2): return "der Rote"
        case (.sau, 0): return "die Alte"
        case (.sau, 1): return "die Blaue"
        case (.sau, 3): return "die Hundsgfickte"
        default: return nil
        }
    }

    static func full(_ deck: Deck, _ rank: Rank, _ suit: Int) -> String {
        let n = name(deck, rank, suit)
        return nickname(deck, rank, suit).map { "\(n) – \($0)" } ?? n
    }
}

/// Item height in points. The slider runs on a log scale so the tiny sizes get as much room as the big ones.
enum CardSize {
    static let min = 8.0
    static let max = 900.0

    static func height(atSlider t: Double) -> Double { min * pow(max / min, t) }
    static func slider(forHeight h: Double) -> Double { log(clamp(h) / min) / log(max / min) }
    static func clamp(_ h: Double) -> Double { Swift.min(max, Swift.max(min, h)) }
}
