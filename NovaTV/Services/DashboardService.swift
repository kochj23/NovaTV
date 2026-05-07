import Foundation
import Combine

@MainActor
final class DashboardService: ObservableObject {
    @Published var state: DashboardState?
    @Published var isConnected = false
    @Published var lastUpdate: Date?

    private var webSocketTask: URLSessionWebSocketTask?
    private let dashboardHost = "192.168.1.6"
    private let dashboardPort = 37450
    private var reconnectDelay: TimeInterval = 1.0

    init() {
        connect()
    }

    func connect() {
        let url = URL(string: "ws://\(dashboardHost):\(dashboardPort)/ws")!
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        reconnectDelay = 1.0
        receiveMessage()
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        if let data = text.data(using: .utf8) {
                            let decoder = JSONDecoder()
                            if let decoded = try? decoder.decode(DashboardState.self, from: data) {
                                self.state = decoded
                                self.lastUpdate = Date()
                            }
                        }
                    default:
                        break
                    }
                    self.receiveMessage()
                case .failure:
                    self.isConnected = false
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func scheduleReconnect() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(reconnectDelay))
            reconnectDelay = min(reconnectDelay * 1.5, 10.0)
            connect()
        }
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    var baseURL: String { "http://\(dashboardHost):\(dashboardPort)" }

    /// Fetches service detail with retry logic: 3 attempts with exponential backoff (1s, 2s, 4s).
    func fetchDetail(service: String) async -> [String: Any]? {
        guard let url = URL(string: "\(baseURL)/api/detail/\(service)") else { return nil }

        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    return try JSONSerialization.jsonObject(with: data) as? [String: Any]
                }
            } catch {
                // Log failure for diagnostics
                print("[NovaTV] fetchDetail(\(service)) attempt \(attempt)/\(maxAttempts) failed: \(error.localizedDescription)")
            }

            // Exponential backoff: 1s, 2s, 4s
            if attempt < maxAttempts {
                let delay = UInt64(1_000_000_000) * UInt64(1 << (attempt - 1))
                try? await Task.sleep(nanoseconds: delay)
            }
        }
        return nil
    }
}
