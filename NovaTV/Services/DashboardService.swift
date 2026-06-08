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

    /// Circular buffer for sparkline metrics (last 86,400 snapshots = 24h at 1/sec)
    @Published var metricsHistory: MetricsRingBuffer = MetricsRingBuffer(capacity: 86400)

    init() {
        connect()
    }

    func connect() {
        guard let url = URL(string: "ws://\(dashboardHost):\(dashboardPort)/ws") else {
            print("[NovaTV] Invalid WebSocket URL — cannot connect")
            return
        }
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        // isConnected set only on first successful message receive (fix #4)
        reconnectDelay = 1.0
        receiveMessage()
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    // Mark connected on first successful receive
                    if !self.isConnected {
                        self.isConnected = true
                    }
                    switch message {
                    case .string(let text):
                        if let data = text.data(using: .utf8) {
                            let decoder = JSONDecoder()
                            if let decoded = try? decoder.decode(DashboardState.self, from: data) {
                                self.state = decoded
                                self.lastUpdate = Date()
                                // Record snapshot for sparkline metrics
                                self.metricsHistory.append(snapshot: MetricsSnapshot(from: decoded))
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

    /// POST an action to nova-control-web (restart, silence, trigger)
    func postAction(service: String, action: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/action/\(service)/\(action)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                return true
            }
        } catch {
            print("[NovaTV] postAction(\(service)/\(action)) failed: \(error.localizedDescription)")
        }
        return false
    }
}

// MARK: - Metrics Sparkline Support

struct MetricsSnapshot {
    let timestamp: Date
    let cpuPercent: Double
    let memoryPercent: Double
    let schedulerSuccessRate: Double
    let activeAgents: Int
    let redisQueueDepth: Int
    let gatewayOnline: Bool

    init(from state: DashboardState) {
        self.timestamp = Date()
        self.cpuPercent = state.system?.cpuPercent ?? 0
        self.memoryPercent = state.system?.memory?.percent ?? 0

        let runs = state.scheduler?.info?.totalRuns ?? 0
        let failures = state.scheduler?.info?.totalFailures ?? 0
        self.schedulerSuccessRate = runs > 0 ? Double(runs - failures) / Double(runs) * 100 : 100

        self.activeAgents = state.agents?.values.filter { $0.status == "running" }.count ?? 0
        self.redisQueueDepth = state.redis?.ingestQueueDepth ?? 0
        self.gatewayOnline = (state.gateway?.ok ?? false) ||
            state.gateway?.status == "ok" ||
            state.gateway?.status == "up" ||
            state.gateway?.gatewayStatus == "live"
    }
}

struct MetricsRingBuffer {
    private var buffer: [MetricsSnapshot?]
    private var writeIndex: Int = 0
    private(set) var count: Int = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    mutating func append(snapshot: MetricsSnapshot) {
        buffer[writeIndex] = snapshot
        writeIndex = (writeIndex + 1) % capacity
        if count < capacity { count += 1 }
    }

    /// Returns ordered snapshots oldest-first
    var snapshots: [MetricsSnapshot] {
        if count < capacity {
            return buffer.prefix(count).compactMap { $0 }
        }
        let tail = buffer[writeIndex...].compactMap { $0 }
        let head = buffer[..<writeIndex].compactMap { $0 }
        return tail + head
    }

    /// Returns last N values for a given metric
    func cpuValues(last n: Int) -> [Double] {
        Array(snapshots.suffix(n).map(\.cpuPercent))
    }

    func memoryValues(last n: Int) -> [Double] {
        Array(snapshots.suffix(n).map(\.memoryPercent))
    }

    func schedulerValues(last n: Int) -> [Double] {
        Array(snapshots.suffix(n).map(\.schedulerSuccessRate))
    }

    func redisQueueValues(last n: Int) -> [Double] {
        Array(snapshots.suffix(n).map { Double($0.redisQueueDepth) })
    }

    func agentValues(last n: Int) -> [Double] {
        Array(snapshots.suffix(n).map { Double($0.activeAgents) })
    }
}
