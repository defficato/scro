import Foundation
import AppKit
import SCROCore

let args = Array(CommandLine.arguments.dropFirst())
let command = args.first ?? "help"
let indexArg = args.dropFirst().first.flatMap(Int.init)

func stderr(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

/// 1-based lookup; 1 = most recent.
func capture(at oneBasedIndex: Int) -> URL? {
    let all = Captures.list()
    guard oneBasedIndex >= 1, oneBasedIndex <= all.count else { return nil }
    return all[oneBasedIndex - 1]
}

func list() -> Int32 {
    let all = Captures.list()
    guard !all.isEmpty else {
        print("no screenshots yet — take one with ⇧⌘4")
        return 0
    }
    let age = RelativeDateTimeFormatter()
    age.unitsStyle = .abbreviated
    for (i, url) in all.enumerated() {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
        let size = ByteCountFormatter.string(fromByteCount: Int64(values?.fileSize ?? 0), countStyle: .file)
        let when = values?.creationDate.map { age.localizedString(for: $0, relativeTo: Date()) } ?? ""
        print(String(format: "%2d  %@  %@  %@", i + 1, url.lastPathComponent, size, when))
    }
    return 0
}

func copy(_ n: Int) -> Int32 {
    guard let url = capture(at: n) else {
        stderr("scro: no screenshot #\(n) (have \(Captures.list().count))")
        return 1
    }
    Clipboard.copy(url: url)
    print("copied #\(n) — \(url.lastPathComponent)")
    return 0
}

func path(_ n: Int) -> Int32 {
    guard let url = capture(at: n) else {
        stderr("scro: no screenshot #\(n) (have \(Captures.list().count))")
        return 1
    }
    print(url.path)
    return 0
}

func reveal(_ n: Int) -> Int32 {
    guard let url = capture(at: n) else {
        stderr("scro: no screenshot #\(n) (have \(Captures.list().count))")
        return 1
    }
    NSWorkspace.shared.activateFileViewerSelecting([url])
    return 0
}

func executablePath() -> URL {
    let arg0 = CommandLine.arguments.first ?? ""
    if arg0.contains("/") {
        return URL(fileURLWithPath: arg0).resolvingSymlinksInPath()
    }
    // argv[0] without a path means we can't locate the real binary.
    return URL(fileURLWithPath: "/Applications/scro.app/Contents/MacOS/scro-cli")
}

func installCLI() -> Int32 {
    let source = executablePath()
    let binDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin", isDirectory: true)
    let link = binDir.appendingPathComponent("scro")
    do {
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: link)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        print("linked \(link.path) → \(source.path)")
        let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        if !pathEntries.contains(binDir.path) {
            print("note: \(binDir.path) is not on your PATH — add this to ~/.zshrc:")
            print("  export PATH=\"$HOME/.local/bin:$PATH\"")
        }
        return 0
    } catch {
        stderr("scro: could not install CLI: \(error.localizedDescription)")
        return 1
    }
}

func uninstallCLI() -> Int32 {
    let link = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/scro")
    guard FileManager.default.fileExists(atPath: link.path) else {
        print("scro CLI is not installed")
        return 0
    }
    if let dest = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path),
       dest.hasSuffix("scro-cli") {
        try? FileManager.default.removeItem(at: link)
        print("removed \(link.path)")
        return 0
    }
    stderr("scro: \(link.path) exists but is not a scro-cli symlink — leaving it alone")
    return 1
}

func usage() {
    print("""
    scro — screenshot tray CLI

    Usage: scro <command> [n]

      list            list captured screenshots (newest first)
      copy [n]        copy screenshot n to clipboard (default: latest)
      path [n]        print file path of screenshot n
      open [n]        reveal screenshot n in Finder
      count           print number of captures
      clear           delete all captures
      dir             print captures directory
      install-cli     link this CLI into ~/.local/bin as `scro`
      uninstall-cli   remove that link
      help            show this help

    n is 1-based; 1 = most recent.
    """)
}

let exitCode: Int32
switch command {
case "list", "ls":
    exitCode = list()
case "copy":
    exitCode = copy(indexArg ?? 1)
case "path":
    exitCode = path(indexArg ?? 1)
case "open":
    exitCode = reveal(indexArg ?? 1)
case "count":
    print(Captures.list().count)
    exitCode = 0
case "clear":
    Captures.clear()
    print("cleared history")
    exitCode = 0
case "dir":
    print(Captures.directory.path)
    exitCode = 0
case "install-cli":
    exitCode = installCLI()
case "uninstall-cli":
    exitCode = uninstallCLI()
case "help", "-h", "--help":
    usage()
    exitCode = 0
default:
    stderr("scro: unknown command '\(command)'")
    usage()
    exitCode = 1
}
exit(exitCode)
