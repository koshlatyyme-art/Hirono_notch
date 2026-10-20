import Foundation
import Testing
@testable import NotchBuddyCore

@Suite struct PasteboardSnapshotTests {
    @Test func concealedIsIgnored() {
        let s = PasteboardSnapshot(types: ["org.nspasteboard.ConcealedType", "public.utf8-plain-text"], string: "hunter2")
        #expect(s.classify() == nil)
    }

    @Test func transientIsIgnored() {
        let s = PasteboardSnapshot(types: ["org.nspasteboard.TransientType", "public.utf8-plain-text"], string: "x")
        #expect(s.classify() == nil)
    }

    @Test func fileURLIsIgnored() {
        let s = PasteboardSnapshot(types: ["public.file-url", "public.utf8-plain-text"], string: "photo.png")
        #expect(s.classify() == nil)
    }

    @Test func browserTextIsText() {
        let s = PasteboardSnapshot(types: ["public.html", "public.utf8-plain-text"], string: "Hello\nworld")
        #expect(s.classify() == .text("Hello\nworld"))
    }

    @Test func addressBarLinkIsLink() {
        let s = PasteboardSnapshot(types: ["public.url", "public.utf8-plain-text"], string: " https://apple.com/mac ")
        #expect(s.classify() == .link(URL(string: "https://apple.com/mac")!))
    }

    @Test(arguments: ["https://a.com\nhttps://b.com", "see https://a.com", "ftp://x.org", "mailto:a@b.c"])
    func linkLookalikesAreText(string: String) {
        let s = PasteboardSnapshot(types: ["public.utf8-plain-text"], string: string)
        #expect(s.classify() == .text(string))
    }

    @Test func screenshotIsImage() {
        let s = PasteboardSnapshot(types: ["public.png"], png: Data([1, 2, 3]))
        #expect(s.classify() == .image(Data([1, 2, 3]), uti: "public.png"))
    }

    @Test func safariCopyImageIsImage() {
        let s = PasteboardSnapshot(types: ["public.tiff", "public.url"], urlString: "https://x/y.jpg", tiff: Data([4]))
        #expect(s.classify() == .image(Data([4]), uti: "public.tiff"))
    }

    @Test func pngPreferredOverTiff() {
        let s = PasteboardSnapshot(types: ["public.png", "public.tiff"], png: Data([1]), tiff: Data([2]))
        #expect(s.classify() == .image(Data([1]), uti: "public.png"))
    }

    @Test func richTextWithRenditionIsText() {
        let s = PasteboardSnapshot(types: ["public.rtf", "public.utf8-plain-text", "com.adobe.pdf", "public.tiff"],
                                   string: "Report", tiff: Data([5]))
        #expect(s.classify() == .text("Report"))
    }

    @Test func whitespaceOnlyIsIgnored() {
        let s = PasteboardSnapshot(types: ["public.utf8-plain-text"], string: "  \n ")
        #expect(s.classify() == nil)
    }

    @Test func urlOnlyTypeIsLink() {
        let s = PasteboardSnapshot(types: ["public.url"], urlString: "https://a.com")
        #expect(s.classify() == .link(URL(string: "https://a.com")!))
    }
}
