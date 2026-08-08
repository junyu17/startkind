import SwiftUI

@main
struct StartKindApp: App {
    @StateObject private var env: AppEnvironment

    init() {
        let args = ProcessInfo.processInfo.arguments
        let isUITest = args.contains("-UITEST") || args.contains("-UITEST_AUTH")
        if isUITest {
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        }
        _env = StateObject(wrappedValue: MainActor.assumeIsolated { AppEnvironment(inMemory: isUITest) })
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
                .environmentObject(LocalizationManager.shared)
                .task { await env.bootstrap() }
                .onOpenURL { env.handleJoinURL($0) }
        }
    }
}
