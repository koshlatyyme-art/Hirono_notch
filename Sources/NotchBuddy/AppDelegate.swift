import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let character = CharacterModel()
    private var controller: NotchController?
    private var input: InputMonitor?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let assets = CharacterAssets.load()
        if assets == nil { NSLog("NotchBuddy: character assets missing from Contents/Resources/Character") }
        controller = NotchController(model: model, character: character, assets: assets)
        model.onExternalCopy = { [unowned self] in
            character.handle(.copied, characterRect: model.characterRect)
        }
        model.startWatchingPasteboard()
        let input = InputMonitor(
            onEvent: { [unowned self] event in character.handle(event, characterRect: model.characterRect) },
            onTick: { [unowned self] idle in character.tick(systemIdle: idle) }
        )
        input.start()
        self.input = input
    }
}
