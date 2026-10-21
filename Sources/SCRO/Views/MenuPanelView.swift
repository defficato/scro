import SwiftUI
import AppKit

struct MenuPanelView: View {
    let store: ScreenshotStore

    var body: some View {
        VStack(spacing: 12) {
            header

            if store.captures.isEmpty {
                emptyState
            } else {
                preview
                if store.captures.count > 1 { filmstrip }
                navRow
                copyButton
            }

            hairline
            footer
        }
        .padding(14)
        .frame(width: 340)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("scro")
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.5)
            Spacer()
            if !store.captures.isEmpty {
                Text("\(store.currentIndex + 1) / \(store.captures.count)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.hoverBackground, in: Capsule())
            }
        }
    }

    // MARK: - Empty state (shadcn dropzone vibe)

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text("No screenshots yet")
                .font(.system(size: 13, weight: .medium))
            Text("Take one with ⇧⌘4 and it will show up here")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius)
                .strokeBorder(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
    }

    // MARK: - Preview card

    private var preview: some View {
        ZStack {
            if let image = store.currentImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(8)
                    .id(store.current)
                    .transition(.opacity)
            }
            if store.showCopied {
                copiedChip
            }
        }
        .animation(.easeOut(duration: 0.15), value: store.currentIndex)
        .animation(.snappy, value: store.showCopied)
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .contentShape(Rectangle())
        .onTapGesture { store.copyCurrentToClipboard() }
        .onDrag { dragItem }
        .help("Click to copy · drag out to drop anywhere")
    }

    private var copiedChip: some View {
        Label("Copied", systemImage: "checkmark")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.primaryForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.primaryBackground, in: Capsule())
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .transition(.opacity)
    }

    // MARK: - Filmstrip

    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 6) {
                    ForEach(Array(store.captures.enumerated()), id: \.element) { index, url in
                        ThumbView(
                            image: store.thumbnail(for: url),
                            isSelected: index == store.currentIndex
                        ) { store.select(index) }
                        .id(url)
                    }
                }
                .padding(2)
            }
            .scrollIndicators(.hidden)
            .frame(height: 42)
            .onChange(of: store.currentIndex) {
                if let current = store.current {
                    withAnimation { proxy.scrollTo(current, anchor: .center) }
                }
            }
        }
    }

    // MARK: - Navigation

    private var navRow: some View {
        HStack(spacing: 8) {
            Button { store.previous() } label: {
                Label("Prev", systemImage: "chevron.left")
            }
            .buttonStyle(OutlineButtonStyle(isEnabled: store.canGoPrevious))
            .disabled(!store.canGoPrevious)

            Button { store.next() } label: {
                Label("Next", systemImage: "chevron.right")
            }
            .buttonStyle(OutlineButtonStyle(isEnabled: store.canGoNext))
            .disabled(!store.canGoNext)
        }
    }

    private var copyButton: some View {
        Button { store.copyCurrentToClipboard() } label: {
            Label("Copy to Clipboard", systemImage: "doc.on.doc")
        }
        .buttonStyle(PrimaryButtonStyle(isEnabled: store.current != nil))
        .disabled(store.current == nil)
    }

    // MARK: - Footer

    private var hairline: some View {
        Rectangle()
            .fill(Theme.cardBorder)
            .frame(height: 1)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text("⇧⌘4 to capture")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
            GhostIconButton(systemImage: "folder", help: "Show in Finder", isEnabled: store.current != nil) {
                showInFinder()
            }
            GhostIconButton(systemImage: "trash", help: "Clear history", danger: true) {
                store.clear()
            }
            GhostIconButton(systemImage: "power", help: "Quit scro") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    // MARK: - Actions

    private var dragItem: NSItemProvider {
        if let url = store.current { return NSItemProvider(object: url as NSURL) }
        return NSItemProvider()
    }

    private func showInFinder() {
        guard let url = store.current else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

// MARK: - Filmstrip thumbnail

private struct ThumbView: View {
    let image: NSImage?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 54, height: 36)
                        .clipped()
                } else {
                    Rectangle().fill(Theme.hoverBackground)
                }
            }
            .frame(width: 54, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor : Theme.cardBorder,
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
