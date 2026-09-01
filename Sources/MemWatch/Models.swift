import Foundation

/// A single OS process as reported by libproc.
struct ProcessSnapshot: Identifiable, Hashable {
    let pid: Int32
    let ppid: Int32
    let rssBytes: UInt64
    let comm: String             // short name (truncated to 16 chars)
    let name: String             // registered full name (may be empty)
    let executablePath: String   // absolute path to the executable
    let user: String             // effective user (best-effort)

    var id: Int32 { pid }

    /// A short label for the row (prefer registered name over comm).
    var displayLabel: String {
        if !name.isEmpty { return name }
        if !comm.isEmpty { return comm }
        return (executablePath as NSString).lastPathComponent
    }
}

/// One .app bundle, with all of its processes aggregated.
struct AppMemoryUsage: Identifiable, Hashable {
    /// If `appPath` is non-nil it's a GUI app. Otherwise it's a system group.
    var appPath: String?
    var displayName: String
    var bundleIdentifier: String?
    var processes: [ProcessSnapshot]
    var totalBytes: UInt64 { processes.reduce(0) { $0 + $1.rssBytes } }

    var id: String { appPath ?? "_system_\(displayName)" }

    var processCount: Int { processes.count }

    /// Sort comparator (descending by total memory).
    static func byMemoryDesc(_ a: AppMemoryUsage, _ b: AppMemoryUsage) -> Bool {
        a.totalBytes > b.totalBytes
    }
}

/// System-wide memory stats from sysctl hw.memsize + vm_statistics64.
struct SystemMemoryUsage {
    var totalBytes: UInt64
    var freeBytes: UInt64        // free pages
    var activeBytes: UInt64
    var inactiveBytes: UInt64
    var wiredBytes: UInt64
    var compressedBytes: UInt64

    var usedBytes: UInt64 { totalBytes - freeBytes }
    var appTrackedBytes: UInt64 = 0   // sum of processes we can attribute

    var freeRatio: Double { totalBytes > 0 ? Double(freeBytes) / Double(totalBytes) : 0 }
}