import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let character = CharacterModel()
    private var controller: NotchController?

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
        model.startWatchingPasteboard()
    }
}
