import StoreKit
import SwiftUI

/// Root tab navigation. Start is the default first screen - never a dashboard.
struct RootView: View {
    private struct RoomCodeRoute: Identifiable {
        let code: String
        var id: String { code }
    }

    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.requestReview) private var requestReview
    @State private var selectedTab: Tab = Self.initialTab
#if DEBUG
    @State private var screenshotTimerRoute: TimerRoute?
#endif

    enum Tab: Hashable { case start, recover, patterns, settings }

    private static var initialTab: Tab {
#if DEBUG
        switch ScreenshotMode.screen {
        case .stuck: return .recover
        case .patterns: return .patterns
        default: return .start
        }
#else
        return .start
#endif
    }

    var body: some View {
        Group {
            if env.onboarding.isComplete {
                mainTabs
            } else {
                OnboardingView()
                    .environmentObject(env)
            }
        }
            .sheet(item: codeJoinRouteBinding) { route in
                CoStartCodeGuestJoinView(roomCode: route.code).environmentObject(env)
            }
            // The decision of *when* to ask lives in AppEnvironment/ReviewPrompter,
            // triggered by a real success (a completed step). This just consumes
            // that one-shot signal and hands off to the system prompt.
            .onChange(of: env.pendingReviewPrompt) { _, shouldPrompt in
                guard shouldPrompt else { return }
                env.pendingReviewPrompt = false
                // A completed step dismisses the timer sheet and may present the
                // save-start sheet behind it. A review request made mid-transition
                // is dropped by iOS, so wait for the churn to settle.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    requestReview()
                }
            }
#if DEBUG
            .onAppear {
                if ScreenshotMode.screen == .timer, screenshotTimerRoute == nil {
                    screenshotTimerRoute = env.makeScreenshotTimerRoute()
                }
            }
            .sheet(isPresented: screenshotSheetIsPresented) { screenshotSheetContent }
#endif
    }

#if DEBUG
    private var screenshotSheetIsPresented: Binding<Bool> {
        Binding(
            get: {
                switch ScreenshotMode.screen {
                case .timer: return screenshotTimerRoute != nil
                case .admin, .settingsPrivacy: return true
                default: return false
                }
            },
            set: { _ in }
        )
    }

    @ViewBuilder
    private var screenshotSheetContent: some View {
        switch ScreenshotMode.screen {
        case .timer:
            if let route = screenshotTimerRoute {
                TimerView(session: route.session, step: route.step) { _, _, _ in }
                    .environmentObject(env)
            }
        case .admin:
            AdminQuickReaderView(initialMode: .text)
                .environmentObject(env)
        case .settingsPrivacy:
            NavigationStack { PrivacyView() }
        default:
            EmptyView()
        }
    }
#endif

    private var codeJoinRouteBinding: Binding<RoomCodeRoute?> {
        Binding(
            get: { env.pendingJoinRoomCode.map { RoomCodeRoute(code: $0) } },
            set: { env.pendingJoinRoomCode = $0?.code }
        )
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
        .environmentObject(MainActor.assumeIsolated { AppEnvironment(inMemory: true) })
}
