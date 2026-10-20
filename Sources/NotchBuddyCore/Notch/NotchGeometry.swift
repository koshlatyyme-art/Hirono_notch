import CoreGraphics

/// Where the notch is and where the panel's shapes go, in AppKit screen coordinates (origin bottom-left).
public struct NotchGeometry: Equatable, Sendable {
    public static let fallbackNotchSize = CGSize(width: 190, height: 32)
    public static let earWidth: CGFloat = 44
    public static let expandedSize = CGSize(width: 520, height: 270)

    public let notchRect: CGRect
    public let isHardwareNotch: Bool
    private let screenFrame: CGRect

    public init(screenFrame: CGRect, safeAreaTop: CGFloat, auxiliaryTopLeft: CGRect?, auxiliaryTopRight: CGRect?) {
        self.screenFrame = screenFrame
        if safeAreaTop > 0, let left = auxiliaryTopLeft, let right = auxiliaryTopRight {
            notchRect = CGRect(x: left.maxX, y: screenFrame.maxY - safeAreaTop,
                               width: right.minX - left.maxX, height: safeAreaTop)
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
}
