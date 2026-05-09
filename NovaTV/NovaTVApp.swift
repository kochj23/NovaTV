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

/// Page names shown in the indicator bar
private let PAGE_NAMES = ["HUD", "DASHBOARD", "JOURNAL", "BIG BROTHER"]
private let PAGE_COUNT = 4

/// Top-level pager. Uses a ZStack + offset animation driven by left/right
/// arrow button presses on the Siri Remote. TabView(.page) doesn't work
/// reliably on tvOS when child views use Canvas or fill the screen.
struct RootView: View {
    @EnvironmentObject var dashboard: DashboardService
    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Pages laid out horizontally, shifted by currentPage
                HStack(spacing: 0) {
                    HUDView()
                        .frame(width: geo.size.width, height: geo.size.height)
                    NavigationStack { DashboardView() }
                        .frame(width: geo.size.width, height: geo.size.height)
                    NavigationStack { JournalDashboardView() }
                        .frame(width: geo.size.width, height: geo.size.height)
                    NavigationStack { BigBrotherDashboardView() }
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(width: geo.size.width * CGFloat(PAGE_COUNT), alignment: .leading)
                .offset(x: -geo.size.width * CGFloat(currentPage) + dragOffset)
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Page indicator bar
                VStack(spacing: 6) {
                    Text(PAGE_NAMES[currentPage])
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.cyan)
                        .animation(.easeInOut, value: currentPage)

                    HStack(spacing: 10) {
                        ForEach(0..<PAGE_COUNT, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? Color.cyan : Color(white: 0.3))
                                .frame(width: i == currentPage ? 28 : 8, height: 6)
                                .animation(.easeInOut(duration: 0.2), value: currentPage)
                        }
                    }
                }
                .padding(.bottom, 24)

                // Invisible focusable buttons at left/right edges — Siri Remote
                // directional pad left/right fires onMoveCommand on tvOS.
                Color.clear
                    .focusable()
                    .onMoveCommand { direction in
                        switch direction {
                        case .left:  if currentPage > 0           { currentPage -= 1 }
                        case .right: if currentPage < PAGE_COUNT-1 { currentPage += 1 }
                        default: break
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(red: 0.02, green: 0.04, blue: 0.12))
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}
