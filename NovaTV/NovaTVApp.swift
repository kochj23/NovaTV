import SwiftUI

@main
struct NovaTVApp: App {
    @StateObject private var dashboard = DashboardService()
    @StateObject private var burnIn = BurnInProtectionManager()
    @StateObject private var layoutProfile = LayoutProfileManager()
    @StateObject private var voiceParser = VoiceCommandParser()
    @State private var memoryService = MemoryScreensaverService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(dashboard)
                .environmentObject(burnIn)
                .environmentObject(layoutProfile)
                .environmentObject(voiceParser)
                .environment(memoryService)
                .preferredColorScheme(.dark)
        }
    }
}

/// Page names shown in the indicator bar
private let PAGE_NAMES = ["HUD", "DASHBOARD", "JOURNAL", "BIG BROTHER", "TRENDS", "MEMORIES"]
private let PAGE_COUNT = 6
private let PAGE_ICONS = ["circle.hexagongrid.fill", "square.grid.2x2.fill", "book.fill", "eye.fill", "chart.xyaxis.line", "text.book.closed.fill"]

/// Top-level pager. Uses a ZStack + offset animation driven by left/right
/// arrow button presses on the Siri Remote. TabView(.page) doesn't work
/// reliably on tvOS when child views use Canvas or fill the screen.
struct RootView: View {
    @EnvironmentObject var dashboard: DashboardService
    @EnvironmentObject var burnIn: BurnInProtectionManager
    @EnvironmentObject var layoutProfile: LayoutProfileManager
    @EnvironmentObject var voiceParser: VoiceCommandParser
    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var showingMenu = false
    @StateObject private var notificationRelay: NotificationRelay = NotificationRelay(baseURL: "http://192.168.1.6:37450")

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
                    TrendsView()
                        .frame(width: geo.size.width, height: geo.size.height)
                    DictionaryScreensaverView()
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
                        burnIn.recordInteraction()
                        switch direction {
                        case .left:  if currentPage > 0            { currentPage -= 1 }
                        case .right: if currentPage < PAGE_COUNT-1 { currentPage += 1 }
                        default: break
                        }
                    }
                    .onPlayPauseCommand {
                        burnIn.recordInteraction()
                        withAnimation(.easeOut(duration: 0.2)) {
                            showingMenu = true
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(red: 0.02, green: 0.04, blue: 0.12))
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .overlay {
            if burnIn.isScreensaverActive {
                DictionaryScreensaverView()
                    .transition(.opacity)
                    .ignoresSafeArea()
            }
        }
        .overlay {
            if showingMenu {
                PageMenuOverlay(isPresented: $showingMenu, currentPage: $currentPage)
                    .transition(.opacity)
            }
        }
        .burnInProtection()
        .onAppear {
            currentPage = layoutProfile.currentProfile.preferredStartPage
            notificationRelay.requestPermission()
        }
        .onChange(of: dashboard.state?.alerts) { _, newAlerts in
            notificationRelay.evaluateAlerts(newAlerts)
        }
    }

}
