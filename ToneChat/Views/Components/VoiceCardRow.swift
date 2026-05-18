import SwiftUI

struct VoiceCardRow: View {
    let persona: Persona
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppTheme.spacingMD) {
                Image(systemName: AppTheme.icon(for: persona.id))
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(persona.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(AppTheme.subtitle(for: persona))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(AppTheme.spacingMD)
            .background(AppTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.5) : AppTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
