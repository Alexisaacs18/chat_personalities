import SwiftUI

struct PersonaIntensityView: View {
    @Binding var intensities: LayerIntensities

    var body: some View {
        VStack(spacing: AppTheme.spacingMD) {
            slider("Core identity", value: $intensities.coreIdentity)
            slider("Speech patterns", value: $intensities.speechPatterns)
            slider("Vocabulary", value: $intensities.vocabulary)
            slider("Examples", value: $intensities.fewShots)
        }
    }

    private func slider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0...1, step: 0.05)
                .tint(AppTheme.accent)
        }
    }
}
