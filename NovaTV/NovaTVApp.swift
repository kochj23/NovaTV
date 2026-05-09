import SwiftUI

@main
struct NovaTVApp: App {
    @StateObject private var dashboard = DashboardService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(dashboard)
                .preferredColorScheme(.dark)
        }
    }
}

/// Top-level pager — swipe left/right on the Siri Remote touch surface to switch views.
struct RootView: View {
    @EnvironmentObject var dashboard: DashboardService
    @State private var currentPage = 0

    // Page order: HUD → Dashboard → Journal → Big Brother
    private let pageCount = 4

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                HUDView()
                    .tag(0)
                NavigationStack { DashboardView() }
                    .tag(1)
                NavigationStack { JournalDashboardView() }
                    .tag(2)
                NavigationStack { BigBrotherDashboardView() }
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Page indicator dots
            HStack(spacing: 10) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage ? Color.cyan : Color(white: 0.35))
                        .frame(width: i == currentPage ? 10 : 7, height: i == currentPage ? 10 : 7)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(red: 0.02, green: 0.04, blue: 0.12))
    }
}
