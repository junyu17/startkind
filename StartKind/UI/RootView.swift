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
        .sheet(isPresented: codeJoinBinding) {
            if let code = env.pendingJoinRoomCode {
                CoStartCodeGuestJoinView(roomCode: code).environmentObject(env)
            }
        }
    }

    private var joinBinding: Binding<Bool> {
        Binding(get: { env.pendingJoinRoomId != nil }, set: { if !$0 { env.pendingJoinRoomId = nil } })
    }

    private var codeJoinBinding: Binding<Bool> {
        Binding(get: { env.pendingJoinRoomCode != nil }, set: { if !$0 { env.pendingJoinRoomCode = nil } })
    }

    private var mainTabs: some View {
        ZStack(alignment: .bottomTrailing) {
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

            Button {
                selectedTab = .start
                env.pendingStuckRestart = true
            } label: {
                Label(L("stuck.button"), systemImage: "lifepreserver.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, Theme.spacing12)
                    .frame(minHeight: Theme.minTapTarget)
                    .foregroundStyle(.white)
                    .background(Theme.accent)
                    .clipShape(Capsule())
                    .shadow(color: Theme.accent.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.trailing, Theme.spacing16)
            .padding(.bottom, 64)
            .accessibilityIdentifier("global.stuck")
        }
    }
}

#Preview {
    RootView()
        .environmentObject(MainActor.assumeIsolated { try! AppEnvironment(inMemory: true) })
}
