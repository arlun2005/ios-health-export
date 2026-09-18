import SwiftUI

struct ExportSetupView: View {
    @Environment(ExportSession.self) private var session

    var body: some View {
        @Bindable var session = session
        List {
            Section {
                Picker("Range", selection: $session.dateRange.preset) {
                    ForEach(DateRangePreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.navigationLink)

                if session.dateRange.preset == .custom {
                    DatePicker("Start", selection: $session.dateRange.customStart, in: ...Date.now, displayedComponents: .date)
                    DatePicker("End", selection: $session.dateRange.customEnd, in: ...Date.now, displayedComponents: .date)
                }

                LabeledContent("Selected days") {
                    Text(rangeCaption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Date range")
            } footer: {
                Text("The end date is included through the end of that calendar day, in your current time zone.")
            }

            Section {
                ForEach(ExportableType.allCases) { type in
                    Toggle(isOn: binding(for: type)) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.title)
                                Text(type.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: type.systemImage)
                        }
                    }
                    .accessibilityHint("Include \(type.title) in the export")
                }
            } header: {
                Text("Data types")
            } footer: {
                Text("v1 exports raw HealthKit samples for steps, heart rate, active energy, sleep analysis, and workouts.")
            }

            Section {
                Button {
                    session.loadPreview()
                } label: {
                    Label("Load preview", systemImage: "list.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!session.canLoad)
            } footer: {
                if session.selectedTypes.isEmpty {
                    Text("Select at least one data type.")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var rangeCaption: String {
        let start = session.dateRange.startDate()
        let end = session.dateRange.inclusiveEndDate()
        return "\(Formatters.fileDate.string(from: start)) → \(Formatters.fileDate.string(from: end))"
    }

    private func binding(for type: ExportableType) -> Binding<Bool> {
        Binding(
            get: { session.selectedTypes.contains(type) },
            set: { isOn in
                if isOn {
                    session.selectedTypes.insert(type)
                } else {
                    session.selectedTypes.remove(type)
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        ExportSetupView()
    }
    .environment(ExportSession())
}
