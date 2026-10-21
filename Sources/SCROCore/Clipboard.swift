import AppKit

public enum Clipboard {
    /// Synchronous copy (CLI). Copies a screenshot so it pastes both as image
    /// data (chat apps, editors) and as a file (Finder, browsers).
    public static func copy(url: URL) {
        write(url: url, data: try? Data(contentsOf: url))
    }

    /// Non-blocking copy for the app: reads the file off the main thread, then
    /// writes the pasteboard. Keeps the panel responsive for multi-MB shots.
    public static func copyAsync(url: URL) {
        Task.detached(priority: .userInitiated) {
            let data = try? Data(contentsOf: url)
            await MainActor.run {
                write(url: url, data: data)
            }
        }
    }

    private static func write(url: URL, data: Data?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        if let data {
            let type: NSPasteboard.PasteboardType = url.pathExtension.lowercased() == "png"
                ? .png
                : NSPasteboard.PasteboardType("public.jpeg")
            item.setData(data, forType: type)
        }
        item.setString(url.absoluteString, forType: .fileURL)
        pasteboard.writeObjects([item])
    }
}
