import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Wirtshaus covers my Mac lives in the menu bar (also reachable in fullscreen: move the pointer to the top edge).
/// It never shows in the Dock.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var settings: NSPanel?
    private var store: CardStore!

    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = CardStore()
        store.onOpenSettings = { [weak self] in self?.showSettings() }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = AppDelegate.menuBarIcon()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        HotKeys.register(keyCode: kVK_ANSI_K) { [weak self] in
            guard let s = self?.store else { return }
            s.setVisible(!s.visible)
        }
        HotKeys.register(keyCode: kVK_ANSI_L) { [weak self] in
            guard let s = self?.store else { return }
            s.setLocked(!s.locked)
        }

        if !UserDefaults.standard.bool(forKey: "didShowWelcome") {
            UserDefaults.standard.set(true, forKey: "didShowWelcome")
            showSettings()
        }
    }

    /// Opening the app again (Finder, Spotlight) brings up the settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    // MARK: Menu

    /// Rebuilt every time it opens, so checkmarks and the deck's cards are current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let hk = HotKeys.modifierSymbols
        let active = store.active

        menu.addItem(ActionItem("Neue Karte") { [unowned self] in self.store.addCard() })
        menu.addItem(store.propsItem())
        menu.addItem(store.deckItem())
        menu.addItem(.separator())

        if let active {
            let title = active.title(store.deck)
            let header = NSMenuItem(title: "Ausgewählt: \(title)", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            if active.isCard {
                menu.addItem(ActionItem("Umdrehen") { [unowned self] in self.store.flip() })
            }
            store.addSliders(to: menu, id: nil)
            menu.addItem(ActionItem("Entfernen") { [unowned self] in self.store.remove() })
            menu.addItem(.separator())
        }

        let show = ActionItem(store.visible ? "Alles ausblenden" : "Alles einblenden") { [unowned self] in
            self.store.setVisible(!self.store.visible)
        }
        show.isEnabled = !store.items.isEmpty
        menu.addItem(show)
        menu.addItem(ActionItem("Fixieren – Klicks gehen durch", on: store.locked) { [unowned self] in
            self.store.setLocked(!self.store.locked)
        })
        let hint = NSMenuItem(title: "Überall: \(hk)K ein/aus · \(hk)L fixieren", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        menu.addItem(ActionItem("Einstellungen …", key: ",") { [unowned self] in self.showSettings() })
        menu.addItem(.separator())
        menu.addItem(ActionItem("Wirtshaus covers my Mac beenden", key: "q") { NSApp.terminate(nil) })
    }

    // MARK: Settings

    /// A non-activating panel too, so opening it over a fullscreen app doesn't leave that Space.
    private func showSettings() {
        if settings == nil {
            let host = NSHostingController(rootView: SettingsView(store: store))
            let p = NSPanel(contentRect: .zero, styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
                            backing: .buffered, defer: false)
            p.contentViewController = host
            p.titlebarAppearsTransparent = true
            p.titleVisibility = .hidden
            p.title = "Wirtshaus covers my Mac"
            p.isMovableByWindowBackground = true
            p.isReleasedWhenClosed = false
            p.hidesOnDeactivate = false
            p.level = .statusBar
            p.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            // a settings panel: only "close" means something here
            p.standardWindowButton(.miniaturizeButton)?.isHidden = true
            p.standardWindowButton(.zoomButton)?.isHidden = true
            p.setContentSize(host.view.fittingSize)
            p.center()
            p.delegate = self
            settings = p
        }
        settings?.makeKeyAndOrderFront(nil)
        settings?.orderFrontRegardless()
    }

    /// Closing the settings frees them completely (SwiftUI and the thumbnails take most of the app's memory).
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSPanel) === settings else { return }
        DispatchQueue.main.async {
            self.settings = nil
            Thumbs.clear()
        }
    }

    /// Two fanned cards, the front one with a spade. Template image, follows the menu bar's colour.
    static func menuBarIcon(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let k = size / 18
            ctx.scaleBy(x: k, y: k)
            func card(_ cx: CGFloat, _ cy: CGFloat, _ angle: CGFloat) -> CGPath {
                var t = CGAffineTransform(translationX: cx, y: cy).rotated(by: angle)
                return CGPath(roundedRect: CGRect(x: -4.6, y: -6.4, width: 9.2, height: 12.8),
                              cornerWidth: 1.6, cornerHeight: 1.6, transform: &t)
            }
            ctx.setStrokeColor(.black)
            ctx.setLineWidth(1.3)
            ctx.addPath(card(6.6, 9.2, 0.26))
            ctx.strokePath()
            // the front card covers the back one, then shows its outline and spade
            let front = card(11.2, 8.8, -0.12)
            ctx.setBlendMode(.clear)
            ctx.addPath(front)
            ctx.fillPath()
            ctx.setBlendMode(.normal)
            ctx.addPath(front)
            ctx.strokePath()
            ctx.saveGState()
            ctx.translateBy(x: 11.2, y: 8.8)
            ctx.rotate(by: -0.12)
            ctx.scaleBy(x: 5.4, y: 5.4)
            ctx.addPath(CardArt.suitPath(.spades))
            ctx.setFillColor(.black)
            ctx.fillPath()
            ctx.restoreGState()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Wirtshaus covers my Mac"
        return image
    }
}
