import SwiftUI
import UIKit

struct AuthorizationView: View {
    @Environment(ExportSession.self) private var session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                typeList
                privacyNote
                Button {
                    Task { await session.requestAccess() }
                } label: {
                    if session.isRequestingAccess {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Continue with Apple Health", systemImage: "heart.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(session.isRequestingAccess)
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "square.and.arrow.up.on.square")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Export your Apple Health data")
                .font(.largeTitle.bold())
            Text("Health Export reads selected HealthKit samples on this iPhone so you can save or share them as CSV or JSON. The app does not write to Apple Health and does not upload your data.")
                .foregroundStyle(.secondary)
        }
    }

    private var typeList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Access we will request")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(ExportableType.allCases) { type in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: type.systemImage)
                            .frame(width: 28)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.title)
                                .font(.body.weight(.semibold))
                            Text(type.subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    if type != ExportableType.allCases.last {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var privacyNote: some View {
        Text("Apple does not tell this app whether you allowed or denied read access. If a type comes back empty after you continue, check Health → Profile → Privacy → Apps → Health Export.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    NavigationStack {
        AuthorizationView()
    }
    .environment(ExportSession())
}
