import SwiftUI
import AppKit

@main
struct MemWatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = ProcessMonitor()

    var body: some Scene {
        Window("MemWatch", id: "main") {
            ContentView(monitor: monitor)
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.titleBar)
        .commands {
            // Replace the default "New" command with our refresh
            CommandGroup(replacing: .newItem) {
                Button("立即刷新") {
                    NotificationCenter.default.post(name: .memWatchRefresh, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandGroup(replacing: .appInfo) {
                Button("关于 MemWatch") {
                    appDelegate.showAboutWindow()
                }
            }

            CommandGroup(replacing: .help) {
                Button("MemWatch 使用说明") {
                    if let url = URL(string: "https://support.apple.com/zh-cn/guide/activity-monitor/welcome/mac") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        MenuBarExtra {
            MenuBarView(monitor: monitor)
        } label: {
            Label(
                MemoryFormatter.compact(monitor.systemMemory.usedBytes),
                systemImage: "memorychip"
            )
        }
        .menuBarExtraStyle(.window)
    }
}

extension Notification.Name {
    static let memWatchRefresh = Notification.Name("MemWatchRefresh")
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showAboutWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "关于 MemWatch"
        window.contentView = NSHostingView(rootView: AboutView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "memorychip")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
            Text("MemWatch")
                .font(.system(size: 20, weight: .semibold))
            Text("按 App 维度查看内存占用，一键关闭进程")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text("版本 1.0")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
