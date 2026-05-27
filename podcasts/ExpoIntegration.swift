// SPDX-License-Identifier: MPL-2.0

//
//  Pocket Casts iOS + Expo Brownfield demo
//
//  Bootstraps the embedded React Native runtime and forwards the host
//  AppDelegate lifecycle into ExpoAppDelegateSubscriberManager so any
//  ExpoAppDelegateSubscriber registered in the embedded runtime gets
//  the full UIApplicationDelegate event stream.
//
//  The PocketCastsLifecycleSubscriber records every event into
//  BrownfieldState("lifecycleEvents"), which the RN Lifecycle Trace
//  screen renders as a live activity feed.
//

#if os(iOS)
    public import Foundation
    public import UIKit
    public import ExpoModulesCore
    internal import PocketCastsExpo

    /// An ExpoAppDelegateSubscriber that pushes every lifecycle callback
    /// into BrownfieldState so the embedded RN screen can render them.
    @objc(PocketCastsLifecycleSubscriber)
    public final class PocketCastsLifecycleSubscriber: ExpoAppDelegateSubscriber {
        nonisolated(unsafe) private static let maxEvents = 40
        nonisolated(unsafe) private static var nextId: Int = 0

        public required init() {
            super.init()
            // Cap once and report 1 active subscriber — we register exactly one.
            BrownfieldState.set("activeSubscribers", 1)
        }

        public func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
        ) -> Bool {
            push(event: "application:didFinishLaunchingWithOptions:")
            return true
        }

        public func applicationDidBecomeActive(_ application: UIApplication) {
            BrownfieldState.set(
                "foregroundCount",
                ((BrownfieldState.get("foregroundCount") as? Int) ?? 0) + 1
            )
            push(event: "applicationDidBecomeActive")
        }

        public func applicationWillResignActive(_ application: UIApplication) {
            push(event: "applicationWillResignActive")
        }

        public func applicationDidEnterBackground(_ application: UIApplication) {
            BrownfieldState.set(
                "backgroundCount",
                ((BrownfieldState.get("backgroundCount") as? Int) ?? 0) + 1
            )
            push(event: "applicationDidEnterBackground")
        }

        public func applicationWillEnterForeground(_ application: UIApplication) {
            push(event: "applicationWillEnterForeground")
        }

        public func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
            BrownfieldState.set(
                "memoryWarnings",
                ((BrownfieldState.get("memoryWarnings") as? Int) ?? 0) + 1
            )
            push(event: "applicationDidReceiveMemoryWarning")
        }

        public func applicationWillTerminate(_ application: UIApplication) {
            push(event: "applicationWillTerminate")
        }

        public func application(
            _ app: UIApplication,
            open url: URL,
            options: [UIApplication.OpenURLOptionsKey: Any] = [:]
        ) -> Bool {
            push(event: "application:openURL:options:", detail: url.absoluteString)
            return false
        }

        public func application(
            _ application: UIApplication,
            continue userActivity: NSUserActivity,
            restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
        ) -> Bool {
            push(event: "application:continue:", detail: userActivity.activityType)
            return false
        }

        public func application(
            _ application: UIApplication,
            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
        ) {
            push(event: "didRegisterForRemoteNotifications", detail: "\(deviceToken.count) bytes")
        }

        // MARK: - State writes

        private func push(event: String, detail: String? = nil) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            let timestamp = formatter.string(from: Date())

            Self.nextId += 1
            let entry: [String: Any] = [
                "id": Self.nextId,
                "name": event,
                "at": timestamp,
                "detail": detail as Any,
            ]

            var current = (BrownfieldState.get("lifecycleEvents") as? [[String: Any]]) ?? []
            current.insert(entry, at: 0)
            if current.count > Self.maxEvents {
                current = Array(current.prefix(Self.maxEvents))
            }
            BrownfieldState.set("lifecycleEvents", current)
        }
    }

    /// Bootstraps the React Native runtime and wires the host AppDelegate's
    /// lifecycle into the Expo subscriber pipeline.
    @objc public final class ExpoIntegration: NSObject {
        @objc public static func bootstrap() {
            ReactNativeHostManager.shared.initialize()
            registerSubscribers()
            registerMessageHandlers()
            observePopToNative()
            seedSharedState()
        }

        /// Register our lifecycle subscriber with the Expo repository.
        /// Subscribers loaded from the modules provider are picked up
        /// automatically, but for a host-owned subscriber we add it here.
        private static func registerSubscribers() {
            let subscriber = PocketCastsLifecycleSubscriber()
            ExpoAppDelegateSubscriberRepository.registerSubscriber(subscriber)
        }

        @objc public static func makeLifecycleViewController() -> UIViewController {
            let rn = ReactNativeViewController(moduleName: "main")
            rn.modalPresentationStyle = .fullScreen
            return rn
        }

        @objc public static func scheduleAutoPresentIfRequested() {
            guard UserDefaults.standard.bool(forKey: "PocketCastsExpoAutoPresent") else { return }
            // Pocket Casts shows a LoadingViewController as rootVC for the
            // first few seconds, then swaps in its real UI (which may
            // present onboarding modals over itself). Wait long enough for
            // that swap to settle before pushing our modal on top.
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                presentOnKeyWindow()
                if UserDefaults.standard.bool(forKey: "PocketCastsExpoAutoDemo") {
                    scheduleDemoActions()
                }
            }
        }

        // MARK: - AppDelegate forwarders
        //
        // Pocket Casts isn't an Expo app — its AppDelegate doesn't inherit
        // ExpoAppDelegate. We forward each event from the host AppDelegate
        // into ExpoAppDelegateSubscriberManager manually so registered
        // subscribers still receive them.

        @objc public static func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
        ) -> Bool {
            ExpoAppDelegateSubscriberManager.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        @objc public static func applicationDidBecomeActive(_ application: UIApplication) {
            ExpoAppDelegateSubscriberManager.applicationDidBecomeActive(application)
        }

        @objc public static func applicationWillResignActive(_ application: UIApplication) {
            ExpoAppDelegateSubscriberManager.applicationWillResignActive(application)
        }

        @objc public static func applicationDidEnterBackground(_ application: UIApplication) {
            ExpoAppDelegateSubscriberManager.applicationDidEnterBackground(application)
        }

        @objc public static func applicationWillEnterForeground(_ application: UIApplication) {
            ExpoAppDelegateSubscriberManager.applicationWillEnterForeground(application)
        }

        @objc public static func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
            ExpoAppDelegateSubscriberManager.applicationDidReceiveMemoryWarning(application)
        }

        @objc public static func applicationWillTerminate(_ application: UIApplication) {
            ExpoAppDelegateSubscriberManager.applicationWillTerminate(application)
        }

        // MARK: - Demo / housekeeping

        private static func scheduleDemoActions() {
            // Cycle a few synthetic lifecycle pulses so the recording shows
            // entries piling up without needing to actually background the
            // app from the simulator.
            let app = UIApplication.shared
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ExpoAppDelegateSubscriberManager.applicationWillResignActive(app)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                ExpoAppDelegateSubscriberManager.applicationDidEnterBackground(app)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                ExpoAppDelegateSubscriberManager.applicationWillEnterForeground(app)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                ExpoAppDelegateSubscriberManager.applicationDidBecomeActive(app)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                ExpoAppDelegateSubscriberManager.applicationDidReceiveMemoryWarning(app)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 9.0) {
                NotificationCenter.default.post(
                    name: Notification.Name("popToNative"),
                    object: nil,
                    userInfo: ["animated": true]
                )
            }
        }

        private static func registerMessageHandlers() {
            _ = BrownfieldMessaging.addListener { message in
                guard let type = message["type"] as? String else { return }
                if type == "CLEAR_EVENTS" {
                    BrownfieldState.set("lifecycleEvents", [] as [[String: Any]])
                    BrownfieldState.set("foregroundCount", 0)
                    BrownfieldState.set("backgroundCount", 0)
                    BrownfieldState.set("memoryWarnings", 0)
                }
            }
        }

        private static func observePopToNative() {
            NotificationCenter.default.addObserver(
                forName: Notification.Name("popToNative"),
                object: nil,
                queue: .main
            ) { note in
                let animated = (note.userInfo?["animated"] as? Bool) ?? false
                dismissPresentation(animated: animated)
            }
        }

        private static func seedSharedState() {
            BrownfieldState.set("lifecycleEvents", [] as [[String: Any]])
            BrownfieldState.set("foregroundCount", 0)
            BrownfieldState.set("backgroundCount", 0)
            BrownfieldState.set("memoryWarnings", 0)
        }

        private static func dismissPresentation(animated: Bool) {
            // The lifecycle screen lives in its own window — just hide that.
            dismissOverlayWindow()
        }

        /// Hold a strong reference to the overlay window so it doesn't get
        /// deallocated the moment `presentOnKeyWindow` returns.
        nonisolated(unsafe) private static var overlayWindow: UIWindow?

        private static func presentOnKeyWindow() {
            guard let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene }).first
            else { return }
            // Pocket Casts swaps its rootViewController during launch
            // (LoadingViewController → onboarding nav → main UI). Presenting
            // on those VCs is unreliable. We instead drop the RN screen
            // into a dedicated UIWindow at .alert level so it sits above
            // whatever the host is doing.
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            window.rootViewController = makeLifecycleViewController()
            window.makeKeyAndVisible()
            overlayWindow = window
        }

        /// Mirror of `dismissPresentation` for the overlay-window approach.
        private static func dismissOverlayWindow() {
            overlayWindow?.isHidden = true
            overlayWindow = nil
        }
    }
#endif
