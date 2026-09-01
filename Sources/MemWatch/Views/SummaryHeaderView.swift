import SwiftUI

/// Top bar: total RAM, used/free split, and a pressure readout.
struct SummaryHeaderView: View {
    let usage: SystemMemoryUsage
    let appCount: Int
    let processCount: Int
    let lastRefresh: Date?
    let isRefreshing: Bool

    private var usedFraction: Double {
        guard usage.totalBytes > 0 else { return 0 }
        return Double(usage.usedBytes) / Double(usage.totalBytes)
    }

    private var pressureColor: Color {
        if usedFraction > 0.9 { return .red }
        if usedFraction > 0.75 { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(MemoryFormatter.string(usage.totalBytes))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("总内存")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 14) {
                    StatPill(
                        label: "已用",
                        value: MemoryFormatter.string(usage.usedBytes),
                        color: pressureColor
                    )
                    StatPill(
                        label: "可用",
                        value: MemoryFormatter.string(usage.freeBytes),
                        color: .green
                    )
                }
            }

            // Stacked bar: freed / app-tracked / wired / cached
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 8)

                    HStack(spacing: 0) {
                        // App memory (red-ish)
                        Rectangle()
                            .fill(Color.red.opacity(0.75))
                            .frame(width: max(0, geo.size.width * appFraction))
                        // Wired (orange)
                        Rectangle()
                            .fill(Color.orange.opacity(0.6))
                            .frame(width: max(0, geo.size.width * wiredFraction))
                        // Compressed (yellow)
                        Rectangle()
                            .fill(Color.yellow.opacity(0.5))
                            .frame(width: max(0, geo.size.width * compressedFraction))
                    }
                    .frame(height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(height: 8)

            HStack(spacing: 12) {
                LegendDot(color: .red.opacity(0.75), label: "应用内存")
                LegendDot(color: .orange.opacity(0.6), label: "联动内存")
                LegendDot(color: .yellow.opacity(0.5), label: "压缩")
                LegendDot(color: Color.primary.opacity(0.08), label: "缓存/可用")

                Spacer()

                HStack(spacing: 4) {
                    if let last = lastRefresh {
                        Text(relativeTime(last))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.4)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .font(.system(size: 10))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.03))
    }

    private var appFraction: Double {
        guard usage.totalBytes > 0 else { return 0 }
        return Double(usage.activeBytes) / Double(usage.totalBytes)
    }

    private var wiredFraction: Double {
        guard usage.totalBytes > 0 else { return 0 }
        return Double(usage.wiredBytes) / Double(usage.totalBytes)
    }

    private var compressedFraction: Double {
        guard usage.totalBytes > 0 else { return 0 }
        return Double(usage.compressedBytes) / Double(usage.totalBytes)
    }

    private func relativeTime(_ date: Date) -> String {
        let delta = Date().timeIntervalSince(date)
        if delta < 5 { return "刚刚更新" }
        if delta < 60 { return "\(Int(delta)) 秒前更新" }
        return "\(Int(delta / 60)) 分钟前更新"
    }
}

struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}
