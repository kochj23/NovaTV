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
}
