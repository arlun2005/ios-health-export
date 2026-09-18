import SwiftUI

@main
struct HealthExportApp: App {
    @State private var session = ExportSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
    }
}
