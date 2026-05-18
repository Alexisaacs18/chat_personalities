import SwiftUI

struct SidebarConversationRow: View {
    let title: String
    let voiceName: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: AppTheme.spacingSM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(voiceName)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.spacingSM)
        .padding(.vertical, AppTheme.spacingSM)
        .background(isSelected ? AppTheme.surfaceElevated : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
            }
        }
    }
}
