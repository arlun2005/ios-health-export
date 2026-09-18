import SwiftUI
import UIKit

struct ExportPreviewView: View {
    @Environment(ExportSession.self) private var session

    var body: some View {
        Group {
            if let payload {
                List {
                    if payload.isEmpty {
                        emptySection
                    } else {
                        summarySection(payload)
                    }

                    if !payload.truncatedTypes.isEmpty {
                        truncationSection(payload)
                    }

                    privacySection
                    exportSection
                }
                .listStyle(.insetGrouped)
            } else {
                ProgressView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Change") {
                    session.returnToSetup()
                }
            }
        }
    }

    private var payload: ExportPayload? { session.payload }

    private var emptySection: some View {
        Section {
            EmptyStateView(
                systemImage: "heart.slash",
                title: "No samples returned",
                message: "HealthKit does not reveal whether read access was denied. This can mean there is no data in the selected range, or that Health Export is not allowed to read the selected types."
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))

            Button {
                openHealthApp()
            } label: {
                Label("Open Health app", systemImage: "heart.text.square")
            }

            Button {
                session.returnToSetup()
            } label: {
                Label("Change range or types", systemImage: "calendar")
            }
        } footer: {
            Text("To review permissions: Health → your profile → Privacy → Apps → Health Export. Enable Steps, Heart Rate, Active Energy, Sleep, and Workouts.")
        }
    }

    private func summarySection(_ payload: ExportPayload) -> some View {
        Section("Preview") {
            LabeledContent("Samples") {
                Text(payload.totalSampleCount.formatted())
            }
            LabeledContent("Range") {
                Text("\(Formatters.fileDate.string(from: payload.startDate)) → \(Formatters.fileDate.string(from: payload.endDateInclusive))")
                    .foregroundStyle(.secondary)
            }
            ForEach(payload.summaries) { summary in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: summary.type.systemImage)
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.type.title)
                            .font(.headline)
                        Text(summary.headline)
                        Text(summary.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func truncationSection(_ payload: ExportPayload) -> some View {
        Section {
            Label(
                "Some types hit the \(ExportLimits.maxSamplesPerType.formatted()) sample cap: \(payload.truncatedTypes.map(\.title).joined(separator: ", ")). Narrow the date range for a complete file.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var privacySection: some View {
        Section {
            Text("Empty types can still mean permission was denied. HealthKit hides that on purpose. Data stays on this iPhone until you share a file.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var exportSection: some View {
        Section("Export") {
            if session.isPreparingFiles && session.files == nil {
                HStack {
                    ProgressView()
                    Text("Preparing files…")
                        .foregroundStyle(.secondary)
                }
            }

            if let files = session.files, session.payload?.isEmpty == false {
                ShareLink(item: files.csvURL, preview: SharePreview("Health CSV", image: Image(systemName: "tablecells"))) {
                    Label("Share CSV", systemImage: "square.and.arrow.up")
                }
                ShareLink(item: files.jsonURL, preview: SharePreview("Health JSON", image: Image(systemName: "curlybraces"))) {
                    Label("Share JSON", systemImage: "square.and.arrow.up")
                }
            } else if session.payload?.isEmpty == false, !session.isPreparingFiles {
                Text("Export files could not be prepared. Try loading the preview again.")
                    .foregroundStyle(.secondary)
            } else if session.payload?.isEmpty == true {
                Text("There is nothing to export for this selection.")
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("Use the Share sheet to save to Files, AirDrop, or another app.")
        }
    }

    private func openHealthApp() {
        guard let url = URL(string: "x-apple-health://") else { return }
        UIApplication.shared.open(url)
    }
}

#Preview("Empty") {
    let session = ExportSession()
    session.phase = .preview
    session.payload = ExportPayload(
        exportedAt: .now,
        startDate: .now,
        endDateInclusive: .now,
        types: ExportableType.allCases,
        records: [],
        summaries: ExportableType.allCases.map {
            TypeSummary(type: $0, sampleCount: 0, truncated: false, headline: "No samples", detail: "Nothing returned for this type")
        },
        truncatedTypes: []
    )
    return NavigationStack {
        ExportPreviewView()
    }
    .environment(session)
}
