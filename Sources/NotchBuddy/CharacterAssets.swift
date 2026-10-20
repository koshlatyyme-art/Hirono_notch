import AppKit
import NotchBuddyCore

/// The cut character: rig.json and one canvas-sized image per layer, from Contents/Resources/Character.
struct CharacterAssets {
    let rig: Rig
    let images: [String: CGImage]

    static func load(from bundle: Bundle = .main) -> CharacterAssets? {
        guard let dir = bundle.resourceURL?.appendingPathComponent("Character"),
              let data = try? Data(contentsOf: dir.appendingPathComponent("rig.json")),
              let rig = try? JSONDecoder().decode(Rig.self, from: data)
        else { return nil }
        var images: [String: CGImage] = [:]
        for layer in rig.layers {
            let url = dir.appendingPathComponent(layer.file) as CFURL
            guard let source = CGImageSourceCreateWithURL(url, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { return nil }
            images[layer.name] = image
        }
        return CharacterAssets(rig: rig, images: images)
    }
}
