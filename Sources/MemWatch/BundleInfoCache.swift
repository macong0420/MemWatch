import Foundation
import AppKit

/// Thread-safe cache for .app bundle metadata.
/// Reading Info.plist + icon is I/O heavy, so we memoize it across refreshes.
/// Not main-actor isolated — accessed from the scanning queue, guarded by a lock.
final class BundleInfoCache {
    static let shared = BundleInfoCache()

    private var store: [String: AppBundleResolver.BundleInfo] = [:]
    private let lock = NSLock()

    private init() {}

    func info(for path: String) -> AppBundleResolver.BundleInfo {
        lock.lock()
        defer { lock.unlock() }
        if let cached = store[path] { return cached }
        let info = AppBundleResolver.bundleInfo(forAppPath: path)
        store[path] = info
        return info
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        store.removeAll()
    }
}
