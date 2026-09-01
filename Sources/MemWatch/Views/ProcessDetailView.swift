import SwiftUI

/// The list of individual processes under one app row.
struct ProcessDetailView: View {
    let app: AppMemoryUsage
    let onKillProcess: (ProcessSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(app.processes.prefix(30)) { proc in
                ProcessRowView(proc: proc) {
                    onKillProcess(proc)
                }
            }
            if app.processes.count > 30 {
                Text("… 还有 \(app.processes.count - 30) 个进程")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
        }
        .padding(.leading, 44)
        .padding(.vertical, 4)
    }
}

struct ProcessRowView: View {
    let proc: ProcessSnapshot
    let onKill: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            // Indent + tree glyph
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 8))
                .foregroundColor(.secondary.opacity(0.5))
                .frame(width: 10)

            // PID
            Text("\(proc.pid)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 46, alignment: .trailing)

            // Name
            Text(proc.displayLabel)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // Executable path (subtle)
            Text(proc.executablePath)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: 260, alignment: .trailing)

            // Memory
            Text(MemoryFormatter.compact(proc.rssBytes))
                .font(.system(size: 11, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 66, alignment: .trailing)

            // Kill single process
            if isHovering {
                Button(action: onKill) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .frame(width: 22, height: 16)
                .help("结束进程 \(proc.pid)")
            } else {
                Color.clear.frame(width: 22, height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovering ? Color.primary.opacity(0.04) : Color.clear)
        )
        .onHover { isHovering = $0 }
    }
}
