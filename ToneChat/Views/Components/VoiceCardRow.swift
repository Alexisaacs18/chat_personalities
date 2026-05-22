import SwiftUI

struct VoiceCardRow: View {
    let persona: Persona
    let isSelected: Bool
    let onSelect: () -> Void
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onReset: (() -> Void)?

    var body: some View {
        HStack(spacing: AppTheme.spacingSM) {
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
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            if let onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.body)
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit \(persona.name)")
            }

            if let onReset, persona.isPreset {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.body)
                        .foregroundStyle(.orange)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset \(persona.name)")
            }

            if let onDelete, !persona.isPreset {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(AppTheme.errorText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(persona.name)")
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
}
