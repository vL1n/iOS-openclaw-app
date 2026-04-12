import Foundation
import SwiftUI
import UIKit
import UserNotifications

protocol PushNotificationManaging: AnyObject {
    var latestDeviceToken: String? { get }
    var routes: AsyncStream<String> { get }
    func requestAuthorization() async -> Bool
    func updateDeviceToken(_ data: Data)
    func route(from userInfo: [AnyHashable: Any])
    func recordFailure(_ error: Error)
}

final class PushNotificationManager: NSObject, PushNotificationManaging, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationManager()

    private let routeContinuation: AsyncStream<String>.Continuation
    let routes: AsyncStream<String>

    private(set) var latestDeviceToken: String?
    private(set) var latestError: String?

    private override init() {
        let parts = AsyncStream.makeStream(of: String.self)
        self.routes = parts.stream
        self.routeContinuation = parts.continuation
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            latestError = error.localizedDescription
            return false
        }
    }

    func updateDeviceToken(_ data: Data) {
        latestDeviceToken = data.map { String(format: "%02x", $0) }.joined()
    }

    func route(from userInfo: [AnyHashable: Any]) {
        if let sessionID = userInfo["sessionId"] as? String {
            routeContinuation.yield(sessionID)
        }
    }

    func recordFailure(_ error: Error) {
        latestError = error.localizedDescription
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        _ = center
        route(from: response.notification.request.content.userInfo)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        _ = center
        _ = notification
        completionHandler([.sound, .banner, .badge])
    }
}
