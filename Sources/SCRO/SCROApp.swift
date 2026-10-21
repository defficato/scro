import SwiftUI
import AppKit

@main
struct SCROApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let store: ScreenshotStore

    @MainActor
    init() {
        store = ScreenshotStore()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView(store: store)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "camera.viewfinder")
                if !store.captures.isEmpty {
                    Text("\(store.captures.count)")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Keep out of App Nap so the screenshot watcher reacts instantly.
        activity = ProcessInfo.processInfo.beginActivity(
            options: .background,
            reason: "Watching for new screenshots"
        )
    }
}
