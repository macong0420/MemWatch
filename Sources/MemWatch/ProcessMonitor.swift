import Foundation
import Darwin

/// Scans all processes, groups them by owning .app bundle, and aggregates
/// memory. Owns the refresh loop.
@MainActor
final class ProcessMonitor: ObservableObject {

    // MARK: - Published state

    @Published private(set) var apps: [AppMemoryUsage] = []
    @Published private(set) var systemMemory = SystemMemoryUsage(
        totalBytes: 0, freeBytes: 0, activeBytes: 0,
        inactiveBytes: 0, wiredBytes: 0, compressedBytes: 0
    )
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshDate: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isAutoRefreshEnabled = true

    private var refreshInterval: TimeInterval = 2.0
    private var timer: Timer?
    private var isScanning = false
    private var hasStarted = false

    // MARK: - Refresh

    func refresh() {
        guard !isScanning else { return }
        isScanning = true
        isRefreshing = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let snapshot = Self.scanSystemMemory()
            let grouped = Self.scanAndGroup()

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.systemMemory = snapshot
                self.apps = grouped
                self.lastRefreshDate = Date()
                self.isRefreshing = false
                self.isScanning = false
                self.lastError = nil
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let seconds = max(0.5, refreshInterval)
        let t = Timer(timeInterval: seconds, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            Task { @MainActor in
                guard self.isAutoRefreshEnabled else { return }
                self.refresh()
            }
        }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        startTimer()
        refresh()
    }

    func setAutoRefresh(_ enabled: Bool) {
        isAutoRefreshEnabled = enabled
    }

    func updateRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = interval
        startTimer()
    }

    // MARK: - Core scanning (nonisolated: runs off the main actor)

    nonisolated private static func scanAndGroup() -> [AppMemoryUsage] {
        let pids = LibProc.listPIDs()

        var appMap: [String: AppMemoryUsage] = [:]
        var systemProcesses: [ProcessSnapshot] = []

        // Pass 1: gather raw process data
        for pid in pids {
            guard let info = LibProc.taskAllInfo(pid: pid) else { continue }
            guard let execPath = LibProc.executablePath(pid: pid), !execPath.isEmpty else { continue }

            let snap = ProcessSnapshot(
                pid: pid,
                ppid: Int32(info.bsd.pbi_ppid),
                rssBytes: info.task.pti_resident_size,
                comm: LibProc.bsdComm(info.bsd),
                name: LibProc.bsdName(info.bsd),
                executablePath: execPath,
                user: userName(uid: info.bsd.pbi_uid)
            )

            if let appPath = AppBundleResolver.appBundlePath(fromExecutablePath: execPath) {
                var entry = appMap[appPath] ?? AppMemoryUsage(
                    appPath: appPath,
                    displayName: "",
                    bundleIdentifier: nil,
                    processes: []
                )
                entry.processes.append(snap)
                appMap[appPath] = entry
            } else {
                systemProcesses.append(snap)
            }
        }

        // Pass 2: fill in display names + bundle ids (cached)
        var groups: [AppMemoryUsage] = []
        for (path, entry) in appMap {
            var e = entry
            let binfo = BundleInfoCache.shared.info(for: path)
            e.displayName = binfo.displayName
            e.bundleIdentifier = binfo.bundleIdentifier
            e.processes.sort { $0.rssBytes > $1.rssBytes }
            groups.append(e)
        }

        // Pass 3: group system processes by executable basename so all
        // `node` / `kernel_task` processes land in one bucket.
        var sysMap: [String: AppMemoryUsage] = [:]
        for snap in systemProcesses {
            let label = Self.labelForSystemProcess(snap)
            var entry = sysMap[label] ?? AppMemoryUsage(
                appPath: nil,
                displayName: label,
                bundleIdentifier: nil,
                processes: []
            )
            entry.processes.append(snap)
            sysMap[label] = entry
        }
        for (_, entry) in sysMap {
            var e = entry
            e.processes.sort { $0.rssBytes > $1.rssBytes }
            groups.append(e)
        }

        groups.sort(by: AppMemoryUsage.byMemoryDesc)
        return groups
    }

    /// Collapse a system process into a bucket name using its executable basename.
    nonisolated private static func labelForSystemProcess(_ snap: ProcessSnapshot) -> String {
        let base = (snap.executablePath as NSString).lastPathComponent
        if base.isEmpty { return "其他系统进程" }
        let trimmed = base
            .replacingOccurrences(of: " Helper", with: "")
            .replacingOccurrences(of: "Helper", with: "")
        return "\(trimmed) · 系统进程"
    }

    nonisolated private static func userName(uid: UInt32) -> String {
        guard let pwd = getpwuid(uid), let cname = pwd.pointee.pw_name else {
            return "\(uid)"
        }
        return String(cString: cname)
    }

    // MARK: - System memory

    nonisolated private static func scanSystemMemory() -> SystemMemoryUsage {
        var total: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &total, &size, nil, 0)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let hostPort = mach_host_self()

        var usage = SystemMemoryUsage(
            totalBytes: total,
            freeBytes: 0,
            activeBytes: 0,
            inactiveBytes: 0,
            wiredBytes: 0,
            compressedBytes: 0
        )

        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return usage }

        let pageSize = UInt64(vm_kernel_page_size)
        usage.freeBytes = UInt64(stats.free_count) * pageSize
        usage.activeBytes = UInt64(stats.active_count) * pageSize
        usage.inactiveBytes = UInt64(stats.inactive_count) * pageSize
        usage.wiredBytes = UInt64(stats.wire_count) * pageSize
        usage.compressedBytes = UInt64(stats.compressor_page_count) * pageSize

        return usage
    }
}
