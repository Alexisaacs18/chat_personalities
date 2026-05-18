import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthService

    private let presets = PresetLoader.loadAll()

    var body: some View {
        MainSplitView(presets: presets)
            .tint(AppTheme.accent)
            .overlay {
                if !auth.isSessionReady {
                    connectionOverlay
                }
            }
            .task {
                await connect()
            }
    }

    private var connectionOverlay: some View {
        VStack(spacing: AppTheme.spacingMD) {
            if auth.authError == nil {
                ProgressView("Connecting…")
            } else {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.errorText)
                Text("Could not connect to server")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(auth.authError ?? "")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                Text(AppConfig.apiBaseURL.absoluteString)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .textSelection(.enabled)
                Button("Try again") {
                    Task { await connect() }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .padding(AppTheme.spacingLG)
        .frame(maxWidth: 320)
        .background(AppTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }

    private func connect() async {
        auth.authError = nil
        do {
            try await auth.ensureSession()
        } catch {
            auth.authError = error.localizedDescription
        }
    }
}
