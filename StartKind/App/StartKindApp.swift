import SwiftUI
import UIKit
import UserNotifications

extension Notification.Name {
    static let startKindNotificationURL = Notification.Name("StartKindNotificationURL")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
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
                .onReceive(NotificationCenter.default.publisher(for: .startKindNotificationURL)) { notification in
                    guard let url = notification.object as? URL else { return }
                    env.handleJoinURL(url)
                }
        }
    }
}
