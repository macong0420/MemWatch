import Foundation
import Darwin

/// Sends SIGTERM/SIGKILL to a group of PIDs. Also tries a graceful
/// "tell application to quit" via osascript when a bundle ID is known.
enum ProcessKiller {

    enum KillResult {
        case allGone           // every PID responded and is gone
        case partial(remaining: [Int32])
        case failed(reason: String)
    }

    /// Kill all processes for an app. Tries graceful shutdown first.
    /// - For apps with a bundle ID: osascript `tell application id "..." to quit`
    /// - After 1.5s, sends SIGTERM to remaining PIDs
    /// - After another 1.5s, sends SIGKILL to whatever is still alive
    static func kill(_ app: AppMemoryUsage, completion: @escaping (KillResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let initialPids = app.processes.map { $0.pid }

            // Step 1: graceful shutdown via osascript (best-effort)
            if let bundleId = app.bundleIdentifier, !bundleId.isEmpty {
                _ = runOsaScript("tell application id \"\(bundleId)\" to quit")
                Thread.sleep(forTimeInterval: 1.5)
            }

            // Step 2: SIGTERM any still alive
            var stillAlive = initialPids.filter { isAlive(pid: $0) }
            for pid in stillAlive {
                _ = Darwin.kill(pid, SIGTERM)
            }
            if !stillAlive.isEmpty {
                Thread.sleep(forTimeInterval: 1.5)
            }

            // Step 3: SIGKILL whatever is left
            stillAlive = stillAlive.filter { isAlive(pid: $0) }
            for pid in stillAlive {
                _ = Darwin.kill(pid, SIGKILL)
            }
            Thread.sleep(forTimeInterval: 0.3)
            stillAlive = stillAlive.filter { isAlive(pid: $0) }

            DispatchQueue.main.async {
                if stillAlive.isEmpty {
                    completion(.allGone)
                } else {
                    completion(.partial(remaining: stillAlive))
                }
            }
        }
    }

    /// True if the PID exists, is signalable, and isn't a zombie.
    ///
    /// Note: `kill(pid, 0)` still succeeds on a zombie (the proc slot lives on
    /// until the parent reaps it), so we additionally check pbi_status != SZOMB.
    /// Otherwise a successful kill would be misreported as "still alive".
    private static func isAlive(pid: Int32) -> Bool {
        let r = Darwin.kill(pid, 0)
        guard r == 0 || errno == EPERM else { return false }

        // Not a zombie? Then it's genuinely running.
        if let info = LibProc.taskAllInfo(pid: pid) {
            return info.bsd.pbi_status != SZOMB
        }
        // Couldn't read status — fall back to the signal check alone.
        return true
    }

    @discardableResult
    private static func runOsaScript(_ source: String) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", source]
        let errPipe = Pipe()
        task.standardError = errPipe
        task.standardOutput = Pipe()
        do {
            try task.run()
        } catch {
            return -1
        }
        task.waitUntilExit()
        return task.terminationStatus
    }
}