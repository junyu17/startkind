import SwiftUI
import UIKit
import UserNotifications

extension Notification.Name {
    static let startKindNotificationURL = Notification.Name("StartKindNotificationURL")
    static let startKindShortcutAction = Notification.Name("StartKindShortcutAction")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var pendingShortcutType: String?
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            Self.pendingShortcutType = shortcut.type
            return false
        }
        return true
    }

    nonisolated func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let type = shortcutItem.type
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .startKindShortcutAction, object: type)
        }
        completionHandler(true)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard let urlString = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: urlString) else {
            completionHandler()
            return
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .startKindNotificationURL, object: url)
        }
        completionHandler()
    }
}

@main
struct StartKindApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var env: AppEnvironment
    @StateObject private var appearance = MainActor.assumeIsolated { AppearanceSettings() }

    init() {
        let isTestRuntime = StartKindRuntime.isTestRuntime
        let usageDefaults: UserDefaults
        if isTestRuntime {
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            let suiteName = "ren.startkind.uitests.usage"
            usageDefaults = UserDefaults(suiteName: suiteName) ?? .standard
            usageDefaults.removePersistentDomain(forName: suiteName)
        } else {
            usageDefaults = .standard
        }
        _env = StateObject(
            wrappedValue: MainActor.assumeIsolated {
                AppEnvironment(inMemory: isTestRuntime, usageDefaults: usageDefaults)
            }
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
                .environmentObject(LocalizationManager.shared)
                .environmentObject(appearance)
                // Applied at the root so the choice reaches every screen,
                // sheet and alert.
                .preferredColorScheme(appearance.theme.colorScheme)
                .environment(\.dynamicTypeSize, appearance.textSize.dynamicTypeSize)
                .task { await env.bootstrap() }
                .onOpenURL { env.handleJoinURL($0) }
                .onAppear {
                    if let type = AppDelegate.pendingShortcutType {
                        AppDelegate.pendingShortcutType = nil
                        env.handleQuickAction(type: type)
                    }
                    env.consumePendingAppIntentAction()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        env.refreshUsage()
                        env.consumePendingAppIntentAction()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .startKindShortcutAction)) { notification in
                    guard let type = notification.object as? String else { return }
                    env.handleQuickAction(type: type)
                }
                .onReceive(NotificationCenter.default.publisher(for: .startKindNotificationURL)) { notification in
                    guard let url = notification.object as? URL else { return }
                    env.handleJoinURL(url)
                }
        }
    }
}
