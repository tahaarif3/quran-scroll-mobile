import SwiftUI
import IqraLockKit
import UIKit

enum MainTab: Hashable {
    case today, read, progress, you
}

struct MainTabView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: MainTab = .today
    @State private var showScreenTimeSetup = false
    @State private var isPromptScheduled = false

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Today", systemImage: "house") }
                .tag(MainTab.today)

            NavigationStack { ReaderView(showsBack: false) }
                .tabItem { Label("Read", systemImage: "book") }
                .tag(MainTab.read)

            ProgressViewScreen()
                .tabItem { Label("Progress", systemImage: "chart.bar") }
                .tag(MainTab.progress)

            YouView()
                .tabItem { Label("You", systemImage: "person") }
                .tag(MainTab.you)
        }
        .tint(IQColor.tabActive)
        .onAppear {
            configureTabBar()
            promptForScreenTimeIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            promptForScreenTimeIfNeeded()
        }
        .sheet(isPresented: $showScreenTimeSetup) {
            ScreenTimeSetupView(isReminder: true)
        }
        .onChange(of: appModel.showReader) { _, show in
            if show {
                tab = .read
                appModel.showReader = false
            }
        }
    }

    /// Asks on every open, for as long as nothing can actually be blocked.
    ///
    /// Deliberately not a one-time nudge. An install that was never connected to Screen Time is
    /// not a preference the user set — it is the app quietly failing at the only thing it claims
    /// to do, while the home screen goes on counting ayahs as though the shield were real. The
    /// reminder stops the moment either missing half is supplied, and "Not now" always gets out.
    private func promptForScreenTimeIfNeeded() {
        // Returning from Apple's picker or from Settings makes the scene active again while this
        // sheet is still up; without the guard that re-presents it on top of itself. The second
        // flag covers onAppear and the scene-phase change both firing on a cold launch.
        guard !showScreenTimeSetup, !isPromptScheduled else { return }
        guard appModel.screenTimeConnection.needsAttention else { return }
        isPromptScheduled = true
        Task {
            // Onboarding hands over mid-transition, and a sheet presented into a view that is
            // still animating in fails to appear at all — silently, which would look exactly
            // like the reminder not working.
            try? await Task.sleep(for: .milliseconds(450))
            isPromptScheduled = false
            // Re-checked rather than trusted: the user may have finished setup from the You tab
            // during the delay.
            guard appModel.screenTimeConnection.needsAttention else { return }
            showScreenTimeSetup = true
        }
    }

    private func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.shadowColor = UIColor(white: 0.85, alpha: 1)
        let inactive = UIColor(
            red: 0xB3 / 255, green: 0xA5 / 255, blue: 0x85 / 255, alpha: 1
        )
        appearance.stackedLayoutAppearance.normal.iconColor = inactive
        // `UIFont(name:size:) as Any` was fatal here. When the font is not registered the
        // initialiser returns nil, `as Any` bridges that to NSNull rather than dropping the
        // entry, and UITabBar.layoutSubviews then sends a font selector to NSNull and aborts —
        // taking the app down on every launch the moment the tab bar appeared.
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: inactive,
            .font: UIFont.iqra("Nunito-SemiBold", size: 10)
        ]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = inactive
    }
}
