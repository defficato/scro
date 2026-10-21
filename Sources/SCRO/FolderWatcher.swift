import Foundation
import Darwin
import SCROCore

/// Watches a folder with FSEvents-via-DispatchSource. Two modes:
/// - `onNewFiles`: reports image files that appear after start (screenshots folder)
/// - `onChange`: reports any change (captures dir — e.g. edits made via the CLI)
/// Debounces so half-written files are not picked up.
@MainActor
final class FolderWatcher {
    private let folder: URL
    private let onNewFiles: (([URL]) -> Void)?
    private let onChange: (() -> Void)?

    private var source: DispatchSourceFileSystemObject?
    private var known = Set<String>()
    private var pendingScan: DispatchWorkItem?
    private var retries = 0

    init(folder: URL, onNewFiles: @escaping ([URL]) -> Void) {
        self.folder = folder
        self.onNewFiles = onNewFiles
        self.onChange = nil
    }

    init(watchingChangesOf folder: URL, onChange: @escaping () -> Void) {
        self.folder = folder
        self.onNewFiles = nil
        self.onChange = onChange
    }

    func start() {
        known = currentImageNames()
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        // Deliver events on the main queue: the watcher is main-actor isolated,
        // and it keeps the runtime isolation checks happy (no cross-thread calls).
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleScan()
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    func stop() {
        pendingScan?.cancel()
        source?.cancel()
        source = nil
    }

    private func scheduleScan(delay: TimeInterval = 0.25) {
        pendingScan?.cancel()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.scan() }
        }
        pendingScan = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func scan() {
        if let onChange {
            onChange()
            return
        }

        let names = currentImageNames()
        let now = Date()
        var fresh: [URL] = []
        var unstable = false

        for name in names where !known.contains(name) {
            let url = folder.appendingPathComponent(name)
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let size = values?.fileSize ?? 0
            let mod = values?.contentModificationDate ?? .distantPast
            // Skip files that are still being written; retry shortly.
            guard size > 0, now.timeIntervalSince(mod) > 0.15 else {
                unstable = true
                continue
            }
            known.insert(name)
            fresh.append(url)
        }

        if unstable, retries < 8 {
            retries += 1
            scheduleScan(delay: 0.25)
        } else {
            retries = 0
        }

        if !fresh.isEmpty {
            fresh.sort {
                let da = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let db = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return da < db
            }
            onNewFiles?(fresh)
        }
    }

    private func currentImageNames() -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return Set(names.filter {
            Captures.imageExtensions.contains(($0 as NSString).pathExtension.lowercased())
        })
    }
}
