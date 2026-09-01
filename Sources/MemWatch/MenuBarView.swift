import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var monitor: ProcessMonitor
    @Environment(\.openWindow) private var openWindow
    @State private var killingAppIDs: Set<String> = []
    @State private var resultMessage: String?

    private var topApps: [AppMemoryUsage] {
        Array(
            monitor.apps
                .filter {
                    $0.appPath != nil
                        && $0.bundleIdentifier != "com.macongcong.memwatch"
                }
                .sorted(by: AppMemoryUsage.byMemoryDesc)
                .prefix(10)
        )
    }

    private var listHeight: CGFloat {
        min(CGFloat(topApps.count) * 50 + 16, 420)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if topApps.isEmpty {
                ProgressView("正在扫描进程…")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(topApps) { app in
                            appRow(app)
                        }
                    }
                    .padding(8)
                }
                .frame(height: listHeight)
            }

            if let resultMessage {
                Divider()
                Text(resultMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }

            Divider()
            footer
        }
        .frame(width: 360)
        .onAppear {
            monitor.start()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("MemWatch")
                    .font(.system(size: 14, weight: .semibold))
                Text("已用内存 \(MemoryFormatter.compact(monitor.systemMemory.usedBytes))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if monitor.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    monitor.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("立即刷新")
            }
        }
        .padding(12)
    }

    private func appRow(_ app: AppMemoryUsage) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "app.fill")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text("\(MemoryFormatter.compact(app.totalBytes)) · \(app.processCount) 个进程")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if killingAppIDs.contains(app.id) {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 48)
            } else {
                Button("关闭") {
                    close(app)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
                .help("立即关闭 \(app.displayName)，不会再次确认")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
    }

    private var footer: some View {
        HStack {
            Button("打开主窗口") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            Spacer()

            Button("退出 MemWatch") {
                NSApp.terminate(nil)
            }
        }
        .buttonStyle(.borderless)
        .font(.system(size: 11))
        .padding(12)
    }

    private func close(_ app: AppMemoryUsage) {
        killingAppIDs.insert(app.id)
        resultMessage = "正在关闭 \(app.displayName)…"

        ProcessKiller.kill(app) { result in
            killingAppIDs.remove(app.id)
            switch result {
            case .allGone:
                resultMessage = "已关闭 \(app.displayName)"
            case .partial(let remaining):
                resultMessage = "\(app.displayName) 仍有 \(remaining.count) 个进程存活"
            case .failed(let reason):
                resultMessage = "关闭失败：\(reason)"
            }
            monitor.refresh()
        }
    }
}
