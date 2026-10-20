import CoreGraphics
import Testing
@testable import NotchBuddyCore

@Test func hardwareNotch() {
    let g = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1728, height: 1117), safeAreaTop: 32,
                          auxiliaryTopLeft: CGRect(x: 0, y: 1085, width: 764, height: 32),
                          auxiliaryTopRight: CGRect(x: 964, y: 1085, width: 764, height: 32))
    #expect(g.isHardwareNotch)
    #expect(g.notchRect == CGRect(x: 764, y: 1085, width: 200, height: 32))
    #expect(g.collapsedRect(showsRightEar: true) == CGRect(x: 720, y: 1085, width: 288, height: 32))
    #expect(g.collapsedRect(showsRightEar: false) == CGRect(x: 720, y: 1085, width: 244, height: 32))
    #expect(g.expandedRect == CGRect(x: 604, y: 947, width: 520, height: 170))
}

@Test func fallbackWithoutNotch() {
    let g = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080), safeAreaTop: 0,
                          auxiliaryTopLeft: nil, auxiliaryTopRight: nil)
    #expect(!g.isHardwareNotch)
    #expect(g.notchRect == CGRect(x: 865, y: 1048, width: 190, height: 32))
}

@Test func fallbackOnSecondaryScreen() {
    let g = NotchGeometry(screenFrame: CGRect(x: 1728, y: -200, width: 1920, height: 1080), safeAreaTop: 0,
                          auxiliaryTopLeft: nil, auxiliaryTopRight: nil)
    #expect(g.notchRect == CGRect(x: 2593, y: 848, width: 190, height: 32))
}

@Test func hardwareNotchOnScreenLeftOfMain() {  // built-in display arranged left of an external main display
    let frame = CGRect(x: -1728, y: 0, width: 1728, height: 1117)
    let global = NotchGeometry(screenFrame: frame, safeAreaTop: 32,
                               auxiliaryTopLeft: CGRect(x: -1728, y: 1085, width: 771, height: 32),
                               auxiliaryTopRight: CGRect(x: -772, y: 1085, width: 772, height: 32))
    let local = NotchGeometry(screenFrame: frame, safeAreaTop: 32,
                              auxiliaryTopLeft: CGRect(x: 0, y: 1085, width: 771, height: 32),
                              auxiliaryTopRight: CGRect(x: 956, y: 1085, width: 772, height: 32))
    let expected = CGRect(x: -957, y: 1085, width: 185, height: 32)
    #expect(global.notchRect == expected)
    #expect(local.notchRect == expected)
}

@Test func screenChoicePrefersTheNotch() {
    #expect(NotchGeometry.screenIndex(safeAreaTops: [0, 32]) == 1)
    #expect(NotchGeometry.screenIndex(safeAreaTops: [32, 0]) == 0)
    #expect(NotchGeometry.screenIndex(safeAreaTops: [0, 0]) == 0)  // no notch: the main (menu bar) screen
}
