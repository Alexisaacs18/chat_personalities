import SwiftUI

struct UsageBarView: View {
    let usage: UsageSnapshot?
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            HStack {
                Text("4-hour usage")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let usage {
                    Text("\(Int(usage.percentUsed.rounded()))%")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(usage.fractionUsed >= 0.9 ? AppTheme.errorText : AppTheme.textSecondary)
                }
            }

            if let usage {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.border.opacity(0.35))
                        Capsule()
                            .fill(barColor(for: usage))
                            .frame(width: max(4, geo.size.width * usage.fractionUsed))
                    }
                }
                .frame(height: 8)

                Text("\(formatCount(usage.totalTokens)) tokens used")
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(spacing: AppTheme.spacingSM) {
                    label("In", count: usage.inputTokens)
                    label("Out", count: usage.outputTokens)
                }

                if let reset = usage.resetDate {
                    Text("Resets \(formatReset(reset))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            } else if !isLoading {
                Text("Send a message to start tracking usage.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(AppTheme.spacingMD)
        .background(AppTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
    }

    private func label(_ title: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
            Text(formatCount(count))
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.surface)
        .clipShape(Capsule())
    }

    private func barColor(for usage: UsageSnapshot) -> Color {
        if usage.fractionUsed >= 0.95 { return AppTheme.errorText }
        if usage.fractionUsed >= 0.75 { return Color.orange }
        return AppTheme.accent
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        }
        if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000)
        }
        return "\(n)"
    }

    private func formatReset(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        if Calendar.current.isDateInToday(date) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "today at \(formatter.string(from: date))"
        }
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
