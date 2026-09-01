import SwiftUI

/// Icon + name + process count + memory + expand + kill button.
struct AppRowView: View {
    let app: AppMemoryUsage
    let isExpanded: Bool
    let isKilling: Bool
    let onToggleExpand: () -> Void
    let onKill: () -> Void

    @State private var isHovering = false

    private var memoryColor: Color {
        let gb = Double(app.totalBytes) / 1_073_741_824.0
        if gb >= 1.5 { return .red }
        if gb >= 0.6 { return .orange }
        if gb >= 0.2 { return .yellow }
        return .green
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // App icon
                if let path = app.appPath {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable()
                        .frame(width: 32, height: 32)
                        .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                } else {
                    Image(systemName: "terminal.fill")
                        .resizable()
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(width: 26, height: 26)
                }

                // Names
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    HStack(spacing: 6) {
                        Text("\(app.processCount) 个进程")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        if let bundleId = app.bundleIdentifier, !bundleId.isEmpty {
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(bundleId)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Memory bar
                MemoryBarView(app: app, color: memoryColor)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(MemoryFormatter.compact(app.totalBytes))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(memoryColor)
                }
                .frame(width: 78, alignment: .trailing)

                // Expand chevron
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "收起进程列表" : "展开进程列表")

                // Kill
                Button(action: onKill) {
                    if isKilling {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 14, height: 14)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "power")
                                .font(.system(size: 9, weight: .bold))
                            Text("关闭")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isKilling)
                .help("退出 \(app.displayName) 的 \(app.processCount) 个进程")
                .frame(width: 66)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color.primary.opacity(0.04) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            )
        }
        .onHover { h in
            isHovering = h
        }
    }
}

/// A thin horizontal bar showing this app's share of the top app's memory.
struct MemoryBarView: View {
    let app: AppMemoryUsage
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(4, geo.size.width * ratio), height: 6)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(width: 70, height: 12)
    }

    private var ratio: CGFloat {
        // Log-ish scale so small apps are still visible next to 4GB monsters
        let gb = Double(app.totalBytes) / 1_073_741_824.0
        let scaled = log10(max(gb, 0.005) * 100.0) / log10(500.0)  // 0.005GB..5GB → 0..1
        return CGFloat(min(max(scaled, 0.04), 1.0))
    }
}
