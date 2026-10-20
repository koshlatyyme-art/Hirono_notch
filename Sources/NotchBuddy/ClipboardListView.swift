import NotchBuddyCore
import SwiftUI

/// The session's copies; click copies an item back, dragging drops it into another app.
struct ClipboardListView: View {
    let model: AppModel

    var body: some View {
        if model.accessDenied {
            message("Нет доступа к буферу. Разрешите вставку в Системных настройках → Конфиденциальность и безопасность")
        } else if model.history.items.isEmpty {
            message("Скопируйте что-нибудь — я запомню последние 10")
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(model.history.items) { item in
                        ClipboardRow(item: item, thumbnail: model.thumbnails[item.id],
                                     imageSize: model.imageSizes[item.id], justCopied: model.justCopiedID == item.id)
                            .contentShape(Rectangle())
                            .onTapGesture { model.copy(item) }
                            .onDrag {
                                model.beginDrag()
                                return model.itemProvider(for: item)
                            }
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.6))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClipboardRow: View {
    let item: ClipboardItem
    let thumbnail: NSImage?
    let imageSize: CGSize?
    let justCopied: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            leading
                .frame(width: 32, height: 32)
                .foregroundStyle(.white.opacity(0.7))
            details
                .frame(maxWidth: .infinity, alignment: .leading)
            if justCopied {
                Label("Скопировано", systemImage: "checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(hovering ? 0.14 : 0.06)))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: justCopied)
    }

    @ViewBuilder private var leading: some View {
        switch item.content {
        case .text:
            Image(systemName: "text.alignleft")
        case .link:
            Image(systemName: "link")
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: "photo")
            }
        }
    }

    @ViewBuilder private var details: some View {
        switch item.content {
        case .text:
            Text(item.previewText ?? "")
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .lineLimit(2)
        case .link(let url):
            VStack(alignment: .leading, spacing: 1) {
                Text(url.host() ?? url.absoluteString)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                let rest = url.path() + (url.query().map { "?" + $0 } ?? "")
                if !rest.isEmpty && rest != "/" {
                    Text(rest)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .lineLimit(1)
        case .image:
            Text(imageSize.map { "Изображение · \(Int($0.width))×\(Int($0.height))" } ?? "Изображение")
                .font(.system(size: 12))
                .foregroundStyle(.white)
        }
    }
}
