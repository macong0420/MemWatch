import Foundation
import AppKit

/// Resolves .app bundle paths, display names, bundle IDs, and icons.
struct AppBundleResolver {

    /// Extract the .app bundle path from an executable path.
    /// e.g. /Applications/Foo.app/Contents/MacOS/Foo -> /Applications/Foo.app
    static func appBundlePath(fromExecutablePath path: String) -> String? {
        let parts = path.split(separator: "/")
        var stack: [String] = []
        for p in parts {
            stack.append(String(p))
            if p.hasSuffix(".app") {
                return "/" + stack.joined(separator: "/")
            }
        }
        return nil
    }

    struct BundleInfo {
        var displayName: String
        var bundleIdentifier: String?
        var icon: NSImage
    }

    /// Read Info.plist for display name + bundle id; fetch icon from NSWorkspace.
    static func bundleInfo(forAppPath path: String) -> BundleInfo {
        let url = URL(fileURLWithPath: path)
        let plistURL = url.appendingPathComponent("Contents/Info.plist")

        var displayName = url.deletingPathExtension().lastPathComponent
        var bundleId: String? = nil

        if let plistData = try? Data(contentsOf: plistURL),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
            if let n = plist["CFBundleDisplayName"] as? String { displayName = n }
            else if let n = plist["CFBundleName"] as? String { displayName = n }
            bundleId = plist["CFBundleIdentifier"] as? String
        }

        // Icon: try the app icon, fall back to file icon
        let icon = NSWorkspace.shared.icon(forFile: path)
        // size: 64 is plenty for list rows
        icon.size = NSSize(width: 32, height: 32)

        return BundleInfo(displayName: displayName, bundleIdentifier: bundleId, icon: icon)
    }
}