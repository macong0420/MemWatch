import Foundation
import Darwin

// MARK: - proc_bsdinfo (sys/proc_info.h)
//
// Layout must match the C struct byte-for-byte. We use tuples of Int8 for
// the char arrays so Swift stores them inline (not as heap refs).

typealias Comm16 = (
    Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
    Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8
)

typealias Name32 = (
    Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
    Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
    Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
    Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8
)

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
    var pbi_comm: Comm16 = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    var pbi_name: Name32 = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
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
    var pbsd = proc_bsdinfo()
    var ptinfo = proc_taskinfo()
}

// MARK: - libproc constants

let PROC_PIDTASKALLINFO: Int32 = 2
let PROC_ALL_PIDS_VAL: UInt32 = 1

// pbi_status values (sys/proc.h)
let SIDL: UInt32 = 1     // being created by fork
let SRUN: UInt32 = 2     // currently runnable
let SSLEEP: UInt32 = 3   // sleeping on an address
let SSTOP: UInt32 = 4    // debugging or suspended
let SZOMB: UInt32 = 5    // awaiting collection by parent

// MARK: - Wrapper

struct ProcTaskAllInfo {
    var bsd: proc_bsdinfo
    var task: proc_taskinfo
}

enum LibProc {
    static func listPIDs(bufferSize: Int = 256 * 1024) -> [Int32] {
        let capacity = bufferSize / MemoryLayout<Int32>.size
        let buf = UnsafeMutablePointer<Int32>.allocate(capacity: capacity)
        defer { buf.deallocate() }
        let returned = proc_listpids(PROC_ALL_PIDS_VAL, 0, buf, Int32(bufferSize))
        let count = Int(returned) / MemoryLayout<Int32>.size
        var pids: [Int32] = []
        pids.reserveCapacity(count)
        for i in 0..<count {
            let pid = buf[i]
            if pid > 0 { pids.append(pid) }
        }
        return pids
    }

    static func taskAllInfo(pid: Int32) -> ProcTaskAllInfo? {
        var info = proc_taskallinfo()
        let size = Int32(MemoryLayout<proc_taskallinfo>.size)
        let ret = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, size)
        guard ret == size else { return nil }
        return ProcTaskAllInfo(bsd: info.pbsd, task: info.ptinfo)
    }

    static func executablePath(pid: Int32) -> String? {
        var buf = [CChar](repeating: 0, count: 4096)
        let ret = proc_pidpath(pid, &buf, UInt32(buf.count))
        if ret > 0 {
            return String(cString: buf)
        }
        return nil
    }

    /// Extract the BSD short name (pbi_comm) as a Swift String.
    static func bsdComm(_ bsd: proc_bsdinfo) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(16)
        let mirror = Mirror(reflecting: bsd.pbi_comm)
        for child in mirror.children {
            if let v = child.value as? Int8 {
                if v == 0 { break }
                bytes.append(UInt8(bitPattern: v))
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Extract the registered process name (pbi_name) as a Swift String.
    static func bsdName(_ bsd: proc_bsdinfo) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(32)
        let mirror = Mirror(reflecting: bsd.pbi_name)
        for child in mirror.children {
            if let v = child.value as? Int8 {
                if v == 0 { break }
                bytes.append(UInt8(bitPattern: v))
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}