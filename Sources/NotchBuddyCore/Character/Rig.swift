import CoreGraphics

/// Mirror of Assets/Character/rig.json (written by tools/rig/cut.py). Coordinates are canvas pixels, origin top-left.
public struct Rig: Codable, Equatable, Sendable {
    public struct Layer: Codable, Equatable, Sendable {
        public var name: String
        public var file: String
        public var parent: String?
        public var pivot: [Double]
    }

    public struct Glow: Codable, Equatable, Sendable {
        public var name: String
        public var parent: String
        public var center: [Double]
        public var radius: Double
        public var color: String
        public var night: Double
    }

    public var canvas: [Double]
    public var frames: [String: [Double]]
    /// Degrees reached when the matching pose value is ±1.
    public var limits: [String: Double]
    /// Back to front.
    public var layers: [Layer]
    public var glows: [Glow]

    public var canvasSize: CGSize { CGSize(width: canvas[0], height: canvas[1]) }

    public func frame(_ name: String) -> CGRect? {
        frames[name].map { CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) }
    }

    public func layer(named name: String) -> Layer? {
        layers.first { $0.name == name }
    }

    /// From the root down to `layer`, inclusive.
    public func chain(to layer: String) -> [Layer] {
        var chain: [Layer] = []
        var current = self.layer(named: layer)
        while let found = current {
            chain.insert(found, at: 0)
            current = found.parent.flatMap(self.layer(named:))
        }
        return chain
    }

    public func unitPivot(of layer: String) -> CGPoint {
        guard let pivot = self.layer(named: layer)?.pivot else { return .zero }
        return CGPoint(x: pivot[0] / canvas[0], y: pivot[1] / canvas[1])
    }

    func limit(_ key: String) -> Double { limits[key] ?? 0 }
}
