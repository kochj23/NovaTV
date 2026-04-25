import SwiftUI

@main
struct NovaTVApp: App {
    @StateObject private var dashboard = DashboardService()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(dashboard)
                .preferredColorScheme(.dark)
        }
    }
}
