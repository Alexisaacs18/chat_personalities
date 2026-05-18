import SwiftUI

struct ChatMessageRow: View {
    let role: String
    let content: String
    let voiceName: String?
    let isStreaming: Bool
    let showVoiceLabel: Bool

    private var isUser: Bool { role == "user" }

    var body: some View {
        if isUser {
            userMessage
        } else {
            assistantMessage
        }
    }

    private var userMessage: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer(minLength: 56)
            Text(content)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, AppTheme.spacingMD)
                .padding(.vertical, AppTheme.spacingSM)
                .background(AppTheme.userBubble)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusBubble, style: .continuous))
        }
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.vertical, AppTheme.spacingXS)
    }

    private var assistantMessage: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            if showVoiceLabel, let voiceName {
                Text(voiceName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            messageText
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.vertical, AppTheme.spacingSM)
    }

    @ViewBuilder
    private var messageText: some View {
        if content.isEmpty && isStreaming {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("Thinking…")
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        } else if isStreaming {
            (Text(content) + Text("▍").foregroundStyle(AppTheme.textSecondary))
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)
        } else if let attributed = Self.attributedMarkdownPreservingLineBreaks(content) {
            Text(attributed)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)
        } else {
            Text(content)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)
        }
    }

    /// Full markdown treats single `\n` as a space, which collapses streamed prose into one block.
    /// Inline-only + preserved whitespace keeps paragraph breaks while still allowing **bold**, etc.
    private static func attributedMarkdownPreservingLineBreaks(_ content: String) -> AttributedString? {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        return try? AttributedString(markdown: content, options: options)
    }
}
