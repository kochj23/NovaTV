// NotificationRelay.swift
// NovaTV — Enterprise Feature #2: Push Notifications via APNs
//
// Monitors critical alerts from the dashboard WebSocket and relays them
// to a paired iPhone via a local relay POST. The relay component (running
// on the Nova server) forwards to APNs. Severity-based throttling prevents
// notification fatigue.
//
// Written by Jordan Koch.

import Foundation

@MainActor
final class NotificationRelay: ObservableObject {
    @Published var lastNotification: RelayedNotification?
    @Published var notificationCount: Int = 0
    @Published var isEnabled: Bool = true

    private let relayEndpoint: String
    private var lastNotifiedBySeverity: [String: Date] = [:]

    // Throttle intervals by severity (seconds)
    private let throttleIntervals: [String: TimeInterval] = [
        "critical": 30,    // Critical: at most every 30s
        "warning": 300,    // Warning: at most every 5 min
        "info": 900        // Info: at most every 15 min
    ]

    init(baseURL: String) {
        self.relayEndpoint = "\(baseURL)/api/notify/push"
    }

    /// Evaluate incoming alerts and push critical ones
    func evaluateAlerts(_ alerts: [AlertItem]?) {
        guard isEnabled, let alerts, !alerts.isEmpty else { return }

        for alert in alerts {
            guard shouldNotify(severity: alert.severity) else { continue }

            Task {
                await sendPushRelay(alert: alert)
            }

            lastNotifiedBySeverity[alert.severity] = Date()
            notificationCount += 1
            lastNotification = RelayedNotification(
                message: alert.message,
                severity: alert.severity,
                timestamp: Date()
            )
        }
    }

    private func shouldNotify(severity: String) -> Bool {
        guard let lastTime = lastNotifiedBySeverity[severity] else { return true }
        let interval = throttleIntervals[severity] ?? 300
        return Date().timeIntervalSince(lastTime) >= interval
    }

    private func sendPushRelay(alert: AlertItem) async {
        guard let url = URL(string: relayEndpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "title": "Nova Alert: \(alert.severity.uppercased())",
            "body": alert.message,
            "category": alert.category,
            "severity": alert.severity,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("[NovaTV] Push relay returned HTTP \(http.statusCode)")
            }
        } catch {
            print("[NovaTV] Push relay failed: \(error.localizedDescription)")
        }
    }

    /// Request notification permission (tvOS has limited UNUserNotification support;
    /// push relay to paired iPhone is the primary notification path).
    func requestPermission() {
        // On tvOS, local notifications have limited API surface.
        // The relay endpoint handles APNs delivery to the paired iPhone.
        print("[NovaTV] Notification relay initialized — push via server relay")
    }
}

struct RelayedNotification: Identifiable {
    let id = UUID()
    let message: String
    let severity: String
    let timestamp: Date
}
