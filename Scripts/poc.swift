// POC v4: use PROC_PIDTASKALLINFO to get bsdinfo + taskinfo in one call
import Foundation
import Darwin

// MAXCOMLEN is 16 in BSD
let MAXCOMLEN = 16
let PROC_PIDTASKALLINFO: Int32 = 2
let PROC_ALL_PIDS_VAL: UInt32 = 1

struct proc_bsdinfo {
    var pbi_flags: UInt32 = 0
    var pbi_status: UInt32 = 0
    var pbi_xstatus: UInt32 = 0
    var pbi_pid: UInt32 = 0
    var pbi_ppid: UInt32 = 0
    var pbi_uid: UInt32 = 0
    var pbi_gid: UInt32 = 0
    var pbi_ruid: UInt32 = 0
    var pbi_rgid: UInt32 = 0
    var pbi_svuid: UInt32 = 0
    var pbi_svgid: UInt32 = 0
    var rfu_1: UInt32 = 0
    var pbi_comm: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    var pbi_name: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    var pbi_nfiles: UInt32 = 0
    var pbi_pgid: UInt32 = 0
    var pbi_pjobc: UInt32 = 0
    var e_tdev: UInt32 = 0
    var e_tpgid: UInt32 = 0
    var pbi_nice: Int32 = 0
    var pbi_start_tvsec: UInt64 = 0
    var pbi_start_tvusec: UInt64 = 0
}

struct proc_taskinfo {
    var pti_virtual_size: UInt64 = 0
    var pti_resident_size: UInt64 = 0
    var pti_total_user: UInt64 = 0
    var pti_total_system: UInt64 = 0
    var pti_threads_user: UInt64 = 0
    var pti_threads_system: UInt64 = 0
    var pti_policy: Int32 = 0
    var pti_faults: Int32 = 0
    var pti_pageins: Int32 = 0
    var pti_cow_faults: Int32 = 0
    var pti_messages_sent: Int32 = 0
    var pti_messages_received: Int32 = 0
    var pti_syscalls_mach: Int32 = 0
    var pti_syscalls_unix: Int32 = 0
    var pti_csw: Int32 = 0
    var pti_threadnum: Int32 = 0
    var pti_numrunning: Int32 = 0
    var pti_priority: Int32 = 0
}

struct proc_taskallinfo {
    var pbsd: proc_bsdinfo = proc_bsdinfo()
    var ptinfo: proc_taskinfo = proc_taskinfo()
}

func getAll(pid: Int32) -> proc_taskallinfo? {
    var info = proc_taskallinfo()
    let size = MemoryLayout<proc_taskallinfo>.size
    let ret = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, Int32(size))
    if ret == Int32(size) {
        return info
    }
    return nil
}

func getExecutablePath(pid: Int32) -> String? {
    var buf = [CChar](repeating: 0, count: 4096)
    let ret = proc_pidpath(pid, &buf, UInt32(buf.count))
    if ret > 0 {
        return String(cString: buf)
    }
    return nil
}

func appBundlePath(from execPath: String) -> String? {
    let parts = execPath.split(separator: "/")
    var stack: [String] = []
    for p in parts {
        stack.append(String(p))
        if p.hasSuffix(".app") {
            return "/" + stack.joined(separator: "/")
        }
    }
    return nil
}

func displayName(fromAppPath path: String) -> String {
    let url = URL(fileURLWithPath: path)
    let plistURL = url.appendingPathComponent("Contents/Info.plist")
    if let plistData = try? Data(contentsOf: plistURL),
       let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
        if let name = plist["CFBundleDisplayName"] as? String { return name }
        if let name = plist["CFBundleName"] as? String { return name }
    }
    return url.deletingPathExtension().lastPathComponent
}

// Get all PIDs
let bufferSize = 256 * 1024
let pidBuffer = UnsafeMutablePointer<Int32>.allocate(capacity: bufferSize / MemoryLayout<Int32>.size)
defer { pidBuffer.deallocate() }

let count = proc_listpids(PROC_ALL_PIDS_VAL, 0, pidBuffer, Int32(bufferSize))
let numPids = Int(count) / MemoryLayout<Int32>.size
print("Found \(numPids) PIDs")

struct TaskAllInfoStatic {
    var pbsd: proc_bsdinfo
    var ptinfo: proc_taskinfo
    init() {
        self.pbsd = proc_bsdinfo()
        self.ptinfo = proc_taskinfo()
    }
}

var appGroups: [String: (pids: [Int32], mem: UInt64)] = [:]
var orphanMem: UInt64 = 0
var orphanCount = 0
var orphanSamples: [(String, UInt64)] = []
var successCount = 0

for i in 0..<numPids {
    let pid = pidBuffer[i]
    if pid <= 0 { continue }
    guard let info = getAll(pid: pid) else { continue }
    successCount += 1
    guard let exec = getExecutablePath(pid: pid) else {
        continue
    }
    let mem = info.ptinfo.pti_resident_size
    if let appPath = appBundlePath(from: exec) {
        var entry = appGroups[appPath] ?? (pids: [], mem: 0)
        entry.pids.append(pid)
        entry.mem += mem
        appGroups[appPath] = entry
    } else {
        orphanMem += mem
        orphanCount += 1
        if orphanSamples.count < 10 && mem > 50 * 1024 * 1024 {
            orphanSamples.append((exec, mem))
        }
    }
}

print("Got full info for \(successCount) PIDs")
print("\nTop 20 apps by memory (RSS):")
print(String(repeating: "=", count: 100))
let top = appGroups.sorted { $0.value.mem > $1.value.mem }.prefix(20)
var grandTotal: UInt64 = 0
for (path, entry) in top {
    let memMB = Double(entry.mem) / 1024.0 / 1024.0
    let name = displayName(fromAppPath: path)
    let namePadded = name.padding(toLength: 30, withPad: " ", startingAt: 0)
    let memStr = String(format: "%9.1f MB", memMB).padding(toLength: 13, withPad: " ", startingAt: 0)
    let procStr = "\(entry.pids.count) procs"
    print("\(namePadded) \(memStr) \(procStr)  \(path)")
    grandTotal += entry.mem
}
print("Orphans: \(orphanCount) procs, \(orphanMem / 1024 / 1024) MB")
for (p, m) in orphanSamples {
    print("  \(m/1024/1024) MB  \(p)")
}
print("\nApp-grouped total: \(grandTotal / 1024 / 1024) MB across \(appGroups.count) apps")