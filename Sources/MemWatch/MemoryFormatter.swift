import Foundation

enum MemoryFormatter {
    /// "1.2 GB", "832.5 MB", "124 KB" — bytes → human readable.
    static func string(_ bytes: UInt64) -> String {
        let units: [(String, Double)] = [
            ("TB", 1024.0 * 1024.0 * 1024.0 * 1024.0),
            ("GB", 1024.0 * 1024.0 * 1024.0),
            ("MB", 1024.0 * 1024.0),
            ("KB", 1024.0),
            ("B", 1.0)
        ]
        let value = Double(bytes)
        for (label, threshold) in units {
            if value >= threshold {
                let n = value / threshold
                if n >= 100 || label == "B" {
                    return String(format: "%.0f %@", n, label)
                } else if n >= 10 {
                    return String(format: "%.1f %@", n, label)
                } else {
                    return String(format: "%.2f %@", n, label)
                }
            }
        }
        return "0 B"
    }

    /// "1.2 GB" without trailing zero noise — used for tight UI like list rows.
    static func compact(_ bytes: UInt64) -> String {
        let units: [(String, Double)] = [
            ("TB", 1024.0 * 1024.0 * 1024.0 * 1024.0),
            ("GB", 1024.0 * 1024.0 * 1024.0),
            ("MB", 1024.0 * 1024.0),
            ("KB", 1024.0),
        ]
        let value = Double(bytes)
        for (label, threshold) in units {
            if value >= threshold {
                let n = value / threshold
                if n >= 100 {
                    return String(format: "%.0f %@", n, label)
                } else if n >= 10 {
                    return String(format: "%.1f %@", n, label)
                } else {
                    return String(format: "%.2f %@", n, label)
                }
            }
        }
        return "\(bytes) B"
    }
}