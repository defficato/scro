import Foundation
import AppKit
import ImageIO
import Observation
import SCROCore

/// Holds the capture history (newest first) and the current selection.
/// Screenshots taken with macOS's built-in tools (⇧⌘3/⇧⌘4) are detected by
/// watching the system screenshot folder, then copied into our own store and
/// auto-copied to the clipboard so ⌘V works immediately.
/// The store folder itself is also watched so CLI changes (e.g. `scro clear`)
/// are reflected live.
@Observable
@MainActor
final class ScreenshotStore {
    static let maxCaptures = 50

    private(set) var captures: [URL] = []   // newest first
    private(set) var currentIndex = 0
    private(set) var currentImage: NSImage?
    private(set) var showCopied = false
    private(set) var thumbnails: [URL: NSImage] = [:]

    let capturesDirectory: URL
    @ObservationIgnored private var watcher: FolderWatcher?
    @ObservationIgnored private var capturesWatcher: FolderWatcher?
    @ObservationIgnored private var copyResetTask: Task<Void, Never>?
    @ObservationIgnored private var pendingThumbnails: Set<URL> = []
    @ObservationIgnored private var imageLoadGeneration = 0

    init() {
        capturesDirectory = Captures.directory
        reloadFromDisk()
        startWatching()
    }

    var current: URL? {
        captures.indices.contains(currentIndex) ? captures[currentIndex] : nil
    }

    var canGoPrevious: Bool { currentIndex < captures.count - 1 } // older
    var canGoNext: Bool { currentIndex > 0 }                      // newer

    func previous() {
        guard canGoPrevious else { return }
        currentIndex += 1
        loadCurrentImage()
    }

    func next() {
        guard canGoNext else { return }
        currentIndex -= 1
        loadCurrentImage()
    }

    func select(_ index: Int) {
        guard captures.indices.contains(index), index != currentIndex else { return }
        currentIndex = index
        loadCurrentImage()
    }

    func clear() {
        Captures.clear()
        captures = []
        currentIndex = 0
        currentImage = nil
        thumbnails = [:]
    }

    func copyCurrentToClipboard() {
        guard let url = current else { return }
        Clipboard.copyAsync(url: url)
        copyResetTask?.cancel()
        showCopied = true
        copyResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            self?.showCopied = false
        }
    }

    /// Downscaled preview for the filmstrip, generated off the main thread
    /// and cached. Returns nil while the thumbnail is being created.
    func thumbnail(for url: URL) -> NSImage? {
        if let thumb = thumbnails[url] { return thumb }
        guard !pendingThumbnails.contains(url) else { return nil }
        pendingThumbnails.insert(url)
        Task.detached(priority: .userInitiated) { [weak self] in
            let thumb = Self.downsample(url: url, maxPixelSize: 112)
            await MainActor.run { [weak self] in
                self?.pendingThumbnails.remove(url)
                if let thumb { self?.thumbnails[url] = thumb }
            }
        }
        return nil
    }

    // MARK: - Private

    private func startWatching() {
        // New screenshots land in the macOS screenshot folder…
        watcher = FolderWatcher(folder: Self.screenshotsFolder()) { [weak self] newFiles in
            Task { @MainActor in self?.ingest(newFiles) }
        }
        watcher?.start()
        // …and our own captures dir may change from the outside (CLI).
        capturesWatcher = FolderWatcher(watchingChangesOf: capturesDirectory) { [weak self] in
            Task { @MainActor in self?.reloadFromDisk() }
        }
        capturesWatcher?.start()
    }

    private func ingest(_ files: [URL]) {
        guard !files.isEmpty else { return }
        let directory = capturesDirectory
        Task.detached(priority: .userInitiated) {
            var created: [URL] = []
            for file in files {
                if let dest = Self.copyIntoStore(file, directory: directory) {
                    created.append(dest)
                }
            }
            await MainActor.run { [weak self] in
                guard let self, !created.isEmpty else { return }
                self.captures.insert(contentsOf: created.reversed(), at: 0)
                self.trimIfNeeded()
                self.currentIndex = 0
                self.loadCurrentImage()
                // Fresh captures go straight to the clipboard, so ⌘V just works.
                if let newest = self.captures.first {
                    Clipboard.copyAsync(url: newest)
                }
            }
        }
    }

    private nonisolated static func copyIntoStore(_ src: URL, directory: URL) -> URL? {
        let ext = src.pathExtension
        let base = src.deletingPathExtension().lastPathComponent
        var dest = directory.appendingPathComponent(src.lastPathComponent)
        var n = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = directory.appendingPathComponent("\(base)-\(n).\(ext)")
            n += 1
        }
        do {
            try FileManager.default.copyItem(at: src, to: dest)
            return dest
        } catch {
            NSLog("scro: failed to copy %@: %@", src.lastPathComponent, error.localizedDescription)
            return nil
        }
    }

    private func trimIfNeeded() {
        while captures.count > Self.maxCaptures {
            let oldest = captures.removeLast()
            thumbnails.removeValue(forKey: oldest)
            try? FileManager.default.removeItem(at: oldest)
        }
    }

    private func reloadFromDisk() {
        captures = Captures.list()
        let valid = Set(captures)
        thumbnails = thumbnails.filter { valid.contains($0.key) }
        trimIfNeeded()
        if !captures.indices.contains(currentIndex) { currentIndex = 0 }
        loadCurrentImage()
    }

    /// Loads a downsampled preview off the main thread — big screenshots never
    /// block the panel. Stale loads are discarded by generation.
    private func loadCurrentImage() {
        guard let url = current else {
            currentImage = nil
            return
        }
        currentImage = nil
        imageLoadGeneration += 1
        let generation = imageLoadGeneration
        Task.detached(priority: .userInitiated) { [weak self] in
            let image = Self.downsample(url: url, maxPixelSize: 1400)
            await MainActor.run { [weak self] in
                guard let self, self.imageLoadGeneration == generation else { return }
                self.currentImage = image
            }
        }
    }

    private nonisolated static func downsample(url: URL, maxPixelSize: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
              ] as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Where macOS saves screenshots (honors `com.apple.screencapture location`).
    static func screenshotsFolder() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let plistURL = home.appendingPathComponent("Library/Preferences/com.apple.screencapture.plist")
        if let dict = NSDictionary(contentsOf: plistURL),
           let location = dict["location"] as? String,
           !location.isEmpty {
            return URL(fileURLWithPath: (location as NSString).expandingTildeInPath)
        }
        return home.appendingPathComponent("Desktop")
    }
}
