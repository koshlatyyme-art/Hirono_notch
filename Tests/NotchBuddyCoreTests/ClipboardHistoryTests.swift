import Foundation
import Testing
@testable import NotchBuddyCore

@Suite struct ClipboardHistoryTests {
    let t0 = Date(timeIntervalSince1970: 0)

    @Test func newestFirst() {
        var h = ClipboardHistory()
        h.add(.text("a"), at: t0)
        h.add(.text("b"), at: t0)
        #expect(h.items.map(\.previewText) == ["b", "a"])
    }

    @Test func capacityIsTen() {
        var h = ClipboardHistory()
        for i in 0...10 { h.add(.text("\(i)"), at: t0) }
        #expect(h.items.count == 10)
        #expect(h.items.first?.previewText == "10")
        #expect(!h.items.contains { $0.previewText == "0" })
    }

    @Test func duplicateMovesToTopKeepingId() {
        var h = ClipboardHistory()
        let a = h.add(.text("a"), at: t0)
        h.add(.text("b"), at: t0.addingTimeInterval(1))
        let t2 = t0.addingTimeInterval(2)
        h.add(.text("a"), at: t2)
        #expect(h.items.count == 2)
        #expect(h.items.first?.id == a.id)
        #expect(h.items.first?.copiedAt == t2)
    }

    @Test func imageDedupByContent() {
        var h = ClipboardHistory()
        h.add(.image(Data([9]), uti: "public.png"), at: t0)
        h.add(.image(Data([9]), uti: "public.png"), at: t0)
        #expect(h.items.count == 1)
    }

    @Test func promoteMovesToTop() {
        var h = ClipboardHistory()
        let a = h.add(.text("a"), at: t0)
        h.add(.text("b"), at: t0)
        let t3 = t0.addingTimeInterval(3)
        h.promote(id: a.id, at: t3)
        #expect(h.items.first?.id == a.id)
        #expect(h.items.first?.copiedAt == t3)
    }

    @Test func clearEmpties() {
        var h = ClipboardHistory()
        h.add(.text("a"), at: t0)
        h.clear()
        #expect(h.items.isEmpty)
    }

    @Test func hugeTextPreviewIsTruncated() {
        let item = ClipboardItem(content: .text(String(repeating: "x", count: 5_000_000)), copiedAt: t0)
        #expect(item.previewText?.count == 301)
        #expect(item.previewText?.hasSuffix("…") == true)
    }

    @Test func previewCollapsesWhitespace() {
        let item = ClipboardItem(content: .text("Hello\n\n  world\t!"), copiedAt: t0)
        #expect(item.previewText == "Hello world !")
    }
}
