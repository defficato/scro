import Foundation

/// Shared access to scro's capture store (`~/Library/Application Support/scro/captures`).
/// Used by both the menu bar app and the CLI — the folder is the source of truth.
public enum Captures {
    public static let directory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("scro/captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    public static let imageExtensions: Set<String> = ["png", "jpg", "jpeg"]

    /// All captures, newest first.
    public static func list() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return files
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted {
                let da = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                let db = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return da > db
            }
    }

    public static func clear() {
        for url in list() { try? FileManager.default.removeItem(at: url) }
    }
}
