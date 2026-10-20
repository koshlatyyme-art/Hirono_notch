import CoreGraphics

/// Where the notch is and where the panel's shapes go, in AppKit screen coordinates (origin bottom-left).
public struct NotchGeometry: Equatable, Sendable {
    public static let fallbackNotchSize = CGSize(width: 190, height: 32)
    public static let earWidth: CGFloat = 44
    /// Just tall enough for the seated character under the notch.
    public static let expandedSize = CGSize(width: 520, height: 170)

    public let notchRect: CGRect
    public let isHardwareNotch: Bool
    private let screenFrame: CGRect

    public init(screenFrame: CGRect, safeAreaTop: CGFloat, auxiliaryTopLeft: CGRect?, auxiliaryTopRight: CGRect?) {
        self.screenFrame = screenFrame
        if safeAreaTop > 0, let left = auxiliaryTopLeft, let right = auxiliaryTopRight {
            // Only the areas' widths are used, so it doesn't matter which coordinate space they come in.
            notchRect = CGRect(x: screenFrame.minX + left.width, y: screenFrame.maxY - safeAreaTop,
                               width: screenFrame.width - left.width - right.width, height: safeAreaTop)
            isHardwareNotch = true
        } else {
            let size = Self.fallbackNotchSize
            notchRect = CGRect(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height,
                               width: size.width, height: size.height)
            isHardwareNotch = false
        }
    }

    /// The notch plus its ears: the character on the left, the clipboard counter on the right.
    public func collapsedRect(showsRightEar: Bool) -> CGRect {
        let rightEar = showsRightEar ? Self.earWidth : 0
        return CGRect(x: notchRect.minX - Self.earWidth, y: notchRect.minY,
                      width: Self.earWidth + notchRect.width + rightEar, height: notchRect.height)
    }

    public var expandedRect: CGRect {
        let size = Self.expandedSize
        return CGRect(x: notchRect.midX - size.width / 2, y: screenFrame.maxY - size.height,
                      width: size.width, height: size.height)
    }

    public var panelFrame: CGRect { expandedRect.union(collapsedRect(showsRightEar: true)) }

    /// The screen with a notch, else the first one (the menu bar's screen).
    public static func screenIndex(safeAreaTops: [CGFloat]) -> Int {
        safeAreaTops.firstIndex { $0 > 0 } ?? 0
    }
}
