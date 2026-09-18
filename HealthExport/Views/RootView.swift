import SwiftUI

struct RootView: View {
    @Environment(ExportSession.self) private var session

    var body: some View {
        NavigationStack {
            Group {
                switch session.phase {
                case .checking:
                    ProgressView("Checking Apple Health…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .unavailable:
                    UnavailableHealthView()
                case .needsAuthorization:
                    AuthorizationView()
                case .setup:
                    ExportSetupView()
                case .loading:
                    loadingView
                case .preview:
                    ExportPreviewView()
                case .failed(let message):
                    FailureView(message: message) {
                        Task { await session.retryFromFailure() }
                    }
                }
            }
            .navigationTitle("Health Export")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await session.start()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading Health samples")
                .font(.headline)
            Text("This can take a moment for long ranges or heart rate data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    session.returnToSetup()
                }
            }
        }
    }
}

#Preview("Root") {
    RootView()
        .environment(ExportSession())
}
