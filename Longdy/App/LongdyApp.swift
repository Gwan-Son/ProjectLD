//
//  LongdyApp.swift
//  Longdy
//
//  Created by 심관혁 on 5/26/26.
//

import SwiftUI
import CloudKit
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        PendingCloudKitShareStore.shared.save(cloudKitShareMetadata)
        Task { @MainActor in
            NotificationCenter.default.post(name: .longdyDidReceivePendingCloudKitShare, object: nil)
        }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        guard notification?.subscriptionID?.hasPrefix("longdy.") == true else {
            completionHandler(.noData)
            return
        }
        Task { @MainActor in
            let changed = await CloudKitChangeCoordinator.shared.handleChange()
            completionHandler(changed ? .newData : .noData)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

extension Notification.Name {
    static let longdyDidReceivePendingCloudKitShare = Notification.Name("longdyDidReceivePendingCloudKitShare")
    static let longdyShouldRefreshCoupleData = Notification.Name("longdyShouldRefreshCoupleData")
}

@main
struct LongdyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onReceive(NotificationCenter.default.publisher(for: .longdyDidReceivePendingCloudKitShare)) { _ in
                    appState.handlePendingCloudKitShare()
                }
                .onReceive(NotificationCenter.default.publisher(for: .longdyShouldRefreshCoupleData)) { _ in
                    appState.refreshCoupleData(force: true)
                }
                .onOpenURL { url in
                    appState.handleIncomingShareURL(url)
                }
        }
    }
}
