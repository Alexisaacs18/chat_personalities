import SwiftUI
import UIKit

struct ChatComposerView: View {
    @Binding var text: String
    let isStreaming: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(AppTheme.border)

            HStack(alignment: .bottom, spacing: AppTheme.spacingSM) {
                TextField("Message…", text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .font(.body)
                    .padding(.horizontal, AppTheme.spacingMD)
                    .padding(.vertical, AppTheme.spacingSM)
                    .background(AppTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusComposer, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusComposer, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )

                Button(action: {
                    if isStreaming {
                        onStop()
                    } else {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSend()
                    }
                }) {
                    Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(sendButtonColor)
                        .clipShape(Circle())
                }
                .disabled(!isStreaming && !canSend)
            }
            .padding(.horizontal, AppTheme.spacingMD)
            .padding(.vertical, AppTheme.spacingSM)
            .background(AppTheme.surface)
        }
    }

    private var sendButtonColor: Color {
        if isStreaming { return AppTheme.accent }
        return canSend ? AppTheme.accent : AppTheme.textSecondary.opacity(0.35)
    }
}
