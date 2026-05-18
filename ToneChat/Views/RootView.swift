import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthService

    private let presets = PresetLoader.loadAll()

    var body: some View {
        MainSplitView(presets: presets)
            .tint(AppTheme.accent)
            .overlay {
                if !auth.isSessionReady {
                    ProgressView("Connecting…")
                        .padding(AppTheme.spacingMD)
                        .background(AppTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                }
            }
            .task {
                do {
                    try await auth.ensureSession()
                } catch {
                    auth.authError = error.localizedDescription
                }
            }
    }
}
