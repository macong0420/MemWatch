import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var monitor: ProcessMonitor
    @State private var searchText = ""
    @State private var expandedAppIDs: Set<String> = []
    @State private var isAutoRefresh = true
    @State private var showOnlyUserApps = false
    @State private var killingAppIDs: Set<String> = []

    // Kill confirmation
    @State private var pendingKillApp: AppMemoryUsage?
    @State private var showKillConfirm = false

    // Kill result toast
    @State private var toastMessage: String?
    @State private var showToast = false

    private var filteredApps: [AppMemoryUsage] {
        var result = monitor.apps

        if showOnlyUserApps {
            result = result.filter { $0.appPath != nil }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter { app in
                app.displayName.lowercased().contains(q)
                    || (app.bundleIdentifier ?? "").lowercased().contains(q)
                    || app.processes.contains { proc in
                        proc.displayLabel.lowercased().contains(q)
                            || proc.executablePath.lowercased().contains(q)
                    }
            }
        }
        return result
    }

    private var filteredTotal: UInt64 {
        filteredApps.reduce(0) { $0 + $1.totalBytes }
    }

    var body: some View {
        VStack(spacing: 0) {
            SummaryHeaderView(
                usage: monitor.systemMemory,
                appCount: monitor.apps.count,
                processCount: monitor.apps.reduce(0) { $0 + $1.processCount },
                lastRefresh: monitor.lastRefreshDate,
                isRefreshing: monitor.isRefreshing
            )

            Divider()

            toolbar

            Divider()

            if filteredApps.isEmpty {
                emptyState
            } else {
                appList
            }

            Divider()

            footer
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            monitor.setAutoRefresh(isAutoRefresh)
            monitor.start()
        }
        .onChange(of: isAutoRefresh) { _, newValue in
            monitor.setAutoRefresh(newValue)
        }
        .confirmationDialog(
            "确认关闭",
            isPresented: $showKillConfirm,
            presenting: pendingKillApp
        ) { app in
            Button("关闭 \(app.processCount) 个进程", role: .destructive) {
                performKill(app)
            }
            Button("取消", role: .cancel) {}
        } message: { app in
            Text("即将退出「\(app.displayName)」及其 \(app.processCount) 个进程，共占用 \(MemoryFormatter.string(app.totalBytes))。\n未保存的数据可能会丢失。")
        }
        .overlay(alignment: .bottom) {
            if showToast, let msg = toastMessage {
                ToastView(message: msg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showToast)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            TextField("搜索应用或进程…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            Spacer()

            Toggle("只看 App", isOn: $showOnlyUserApps)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.system(size: 11))

            Toggle("自动刷新", isOn: $isAutoRefresh)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.system(size: 11))

            Button {
                monitor.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("立即刷新")
            .disabled(monitor.isRefreshing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - List

    private var appList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(filteredApps) { app in
                    VStack(spacing: 0) {
                        AppRowView(
                            app: app,
                            isExpanded: expandedAppIDs.contains(app.id),
                            isKilling: killingAppIDs.contains(app.id),
                            onToggleExpand: {
                                toggleExpanded(app.id)
                            },
                            onKill: {
                                pendingKillApp = app
                                showKillConfirm = true
                            }
                        )
                        .padding(.horizontal, 12)

                        if expandedAppIDs.contains(app.id) {
                            ProcessDetailView(app: app) { proc in
                                killSingleProcess(proc, in: app)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("共 \(filteredApps.count) 个应用 · \(MemoryFormatter.string(filteredTotal))")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            if let err = monitor.lastError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }

            Text("⌘R 刷新 · ⌘F 搜索")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.4))
            Text(searchText.isEmpty ? "正在扫描进程…" : "没有匹配的应用")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            if !searchText.isEmpty {
                Button("清除搜索") { searchText = "" }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func toggleExpanded(_ id: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if expandedAppIDs.contains(id) {
                expandedAppIDs.remove(id)
            } else {
                expandedAppIDs.insert(id)
            }
        }
    }

    private func performKill(_ app: AppMemoryUsage) {
        killingAppIDs.insert(app.id)
        ProcessKiller.kill(app) { result in
            killingAppIDs.remove(app.id)
            switch result {
            case .allGone:
                showToast("已关闭 \(app.displayName)")
            case .partial(let remaining):
                showToast("\(app.displayName) 仍有 \(remaining.count) 个进程存活（可能需要管理员权限）")
            case .failed(let reason):
                showToast("关闭失败：\(reason)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                monitor.refresh()
            }
        }
    }

    private func killSingleProcess(_ proc: ProcessSnapshot, in app: AppMemoryUsage) {
        killingAppIDs.insert(app.id)
        let singleApp = AppMemoryUsage(
            appPath: nil,
            displayName: "\(proc.displayLabel) (PID \(proc.pid))",
            bundleIdentifier: nil,
            processes: [proc]
        )
        ProcessKiller.kill(singleApp) { result in
            killingAppIDs.remove(app.id)
            switch result {
            case .allGone:
                showToast("已结束进程 \(proc.pid)")
            case .partial:
                showToast("进程 \(proc.pid) 无法结束")
            case .failed(let reason):
                showToast("失败：\(reason)")
            }
            monitor.refresh()
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showToast = false
            }
        }
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
            )
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
    }
}
