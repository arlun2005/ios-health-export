import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct UnavailableHealthView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Apple Health unavailable", systemImage: "iphone.slash")
        } description: {
            Text("HealthKit is not available here. The iOS Simulator cannot export real Apple Health data. Open this project on a Mac, sign in with your Apple Developer team, and run Health Export on a physical iPhone.")
        }
        .padding()
    }
}

struct FailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview("Unavailable") {
    UnavailableHealthView()
}
