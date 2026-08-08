import SwiftUI

/// Root tab navigation. Start is the default first screen - never a dashboard.
struct RootView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @State private var selectedTab: Tab = .start

    enum Tab: Hashable { case start, recover, patterns, settings }

    var body: some View {
        Group {
            if env.hasStarted {
                mainTabs
            } else {
                AuthView()
            }
        }
        .sheet(isPresented: joinBinding) {
            if let id = env.pendingJoinRoomId {
                CoStartGuestJoinView(roomId: id).environmentObject(env)
            }
        }
    }

    private var joinBinding: Binding<Bool> {
        Binding(get: { env.pendingJoinRoomId != nil }, set: { if !$0 { env.pendingJoinRoomId = nil } })
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            StartView()
                .tabItem { Label(L("tab.start"), systemImage: "play.circle.fill") }
                .tag(Tab.start)
            RecoverView()
                .tabItem { Label(L("tab.recover"), systemImage: "arrow.uturn.backward.circle") }
                .tag(Tab.recover)
            PatternsView()
                .tabItem { Label(L("tab.patterns"), systemImage: "waveform.path.ecg") }
                .tag(Tab.patterns)
            SettingsView()
                .tabItem { Label(L("tab.settings"), systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(Theme.accent)
    }
}

#Preview {
    RootView()
        .environmentObject(MainActor.assumeIsolated { try! AppEnvironment(inMemory: true) })
}
