import SwiftUI
import IqraLockKit

enum MainTab: Hashable {
    case today, read, progress, you
}

struct MainTabView: View {
    @Environment(AppModel.self) private var appModel
    @State private var tab: MainTab = .today

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(MainTab.today)

            NavigationStack {
                ReaderView()
            }
            .tabItem { Label("Read", systemImage: "book") }
            .tag(MainTab.read)

            ProgressViewScreen()
                .tabItem { Label("Progress", systemImage: "chart.bar") }
                .tag(MainTab.progress)

            YouView()
                .tabItem { Label("You", systemImage: "person") }
                .tag(MainTab.you)
        }
        .tint(IQColor.olive)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.white
            appearance.shadowColor = UIColor(white: 0.85, alpha: 1)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().unselectedItemTintColor = UIColor(red: 0xB3 / 255, green: 0xA5 / 255, blue: 0x85 / 255, alpha: 1)
        }
        .onChange(of: appModel.showReader) { _, show in
            if show {
                tab = .read
                appModel.showReader = false
            }
        }
    }
}

import UIKit
