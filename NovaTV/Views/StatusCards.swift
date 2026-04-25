import SwiftUI

struct CardContainer<Content: View>: View {
    let title: String
    let status: CardStatus
    let content: Content

    init(title: String, status: CardStatus = .unknown, @ViewBuilder content: () -> Content) {
        self.title = title
        self.status = status
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)
                Spacer()
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                    .shadow(color: status.color.opacity(0.5), radius: 4)
            }
            content
        }
        .padding(20)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(status.borderColor, lineWidth: 1)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(status.color)
                .frame(height: 2)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
        }
    }
}

enum CardStatus {
    case healthy, degraded, down, unknown

    var color: Color {
        switch self {
        case .healthy: .green
        case .degraded: .yellow
        case .down: .red
        case .unknown: .gray
        }
    }

    var borderColor: Color {
        Color.cyan.opacity(0.1)
    }

    init(from status: String?) {
        switch status {
        case "ok", "up", "running", "live": self = .healthy
        case "degraded", "slow", "warning": self = .degraded
        case "down", "error", "stopped": self = .down
        default: self = .unknown
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 18, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}

struct ProgressBarView: View {
    let percent: Double
    var warningAt: Double = 70
    var criticalAt: Double = 90

    var barColor: Color {
        if percent >= criticalAt { return .red }
        if percent >= warningAt { return .yellow }
        return .green
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(width: geo.size.width * min(percent, 100) / 100)
            }
        }
        .frame(height: 6)
    }
}

func formatUptime(_ seconds: Int?) -> String {
    guard let s = seconds, s > 0 else { return "---" }
    let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
    var parts: [String] = []
    if d > 0 { parts.append("\(d)d") }
    if h > 0 { parts.append("\(h)h") }
    parts.append("\(m)m")
    return parts.joined(separator: " ")
}

// MARK: - Individual Cards

struct SystemCard: View {
    let state: SystemState?
    var body: some View {
        CardContainer(title: "System", status: state?.status == "ok" ? .healthy : .unknown) {
            if let sys = state {
                let cpu = sys.cpuPercent ?? 0
                let mem = sys.memory?.percent ?? 0
                StatRow(label: "CPU", value: String(format: "%.1f%%", cpu), color: cpu > 80 ? .red : cpu > 50 ? .yellow : .green)
                ProgressBarView(percent: cpu, warningAt: 50, criticalAt: 80)
                StatRow(label: "Memory", value: "\(sys.memory?.usedGb ?? 0)/\(sys.memory?.totalGb ?? 0) GB", color: mem > 85 ? .red : .green)
                ProgressBarView(percent: mem, warningAt: 70, criticalAt: 85)
                if let disks = sys.disks {
                    ForEach(Array(disks.sorted(by: { $0.key < $1.key })), id: \.key) { mount, disk in
                        let label = mount == "/" || mount == "/System/Volumes/Data" ? "SSD" : mount.replacingOccurrences(of: "/Volumes/", with: "")
                        StatRow(label: label, value: "\(disk.freeGb ?? 0) GB free", color: (disk.percent ?? 0) > 90 ? .red : .green)
                        ProgressBarView(percent: disk.percent ?? 0, warningAt: 80, criticalAt: 90)
                    }
                }
            } else {
                Text("Connecting...").foregroundStyle(.secondary)
            }
        }
    }
}

struct GatewayCard: View {
    let state: GatewayState?
    var body: some View {
        CardContainer(title: "Gateway", status: CardStatus(from: state?.ok == true ? "ok" : "down")) {
            StatRow(label: "Status", value: state?.gatewayStatus ?? "?", color: state?.ok == true ? .green : .red)
            StatRow(label: "WebSocket", value: state?.wsReachable == true ? "Reachable" : "Down", color: state?.wsReachable == true ? .green : .red)
        }
    }
}

struct SchedulerCard: View {
    let state: SchedulerState?
    var body: some View {
        CardContainer(title: "Scheduler", status: CardStatus(from: state?.status)) {
            if let info = state?.info {
                StatRow(label: "Uptime", value: formatUptime(info.uptimeS), color: .cyan)
                StatRow(label: "Jobs", value: "\(info.tasksTotal ?? 0)")
                StatRow(label: "Running", value: "\(info.tasksRunning ?? 0)", color: (info.tasksRunning ?? 0) > 0 ? .cyan : .primary)
                StatRow(label: "Total Runs", value: "\(info.totalRuns ?? 0)")
                let rate = info.totalRuns ?? 0 > 0 ? Double((info.totalRuns ?? 0) - (info.totalFailures ?? 0)) / Double(info.totalRuns ?? 1) * 100 : 0
                StatRow(label: "Success", value: String(format: "%.1f%%", rate), color: rate >= 98 ? .green : .yellow)
            }
        }
    }
}

struct OllamaCard: View {
    let state: OllamaState?
    var body: some View {
        CardContainer(title: "Ollama", status: CardStatus(from: state?.status)) {
            StatRow(label: "Models", value: "\(state?.modelCount ?? 0)", color: .cyan)
            StatRow(label: "VRAM", value: "\(state?.totalVramGb ?? 0) GB", color: .purple)
            if let models = state?.models {
                ForEach(models, id: \.name) { m in
                    HStack {
                        Text(m.name ?? "?")
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundStyle(.cyan)
                        Spacer()
                        Text("\(m.vramGb ?? 0) GB")
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct PostgresCard: View {
    let state: PostgresState?
    var body: some View {
        CardContainer(title: "PostgreSQL", status: CardStatus(from: state?.status)) {
            StatRow(label: "Size", value: "\(state?.dbSizeGb ?? 0) GB", color: .purple)
            StatRow(label: "Rows", value: formatNumber(state?.totalRows ?? 0), color: .cyan)
            StatRow(label: "Indexes", value: "\(state?.indexCount ?? 0)")
        }
    }
}

struct RedisCard: View {
    let state: RedisState?
    var body: some View {
        let qd = state?.ingestQueueDepth ?? 0
        CardContainer(title: "Redis", status: CardStatus(from: state?.status)) {
            StatRow(label: "Status", value: state?.status == "ok" ? "Connected" : "Down", color: state?.status == "ok" ? .green : .red)
            StatRow(label: "Keys", value: "\(state?.dbSize ?? 0)")
            StatRow(label: "Ingest Queue", value: "\(qd)", color: qd > 50 ? .red : qd > 20 ? .yellow : .green)
        }
    }
}

struct TaskHistoryCard: View {
    let state: TaskHistoryState?
    var body: some View {
        CardContainer(title: "Task History", status: CardStatus(from: state?.status)) {
            if let all = state?.allTime {
                StatRow(label: "Succeeded", value: formatNumber(all["succeeded"] ?? 0), color: .green)
                StatRow(label: "Failed", value: "\(all["failed"] ?? 0)", color: (all["failed"] ?? 0) > 0 ? .red : .green)
                StatRow(label: "Timed Out", value: "\(all["timed_out"] ?? 0)", color: (all["timed_out"] ?? 0) > 0 ? .yellow : .primary)
            }
        }
    }
}

struct ModelUsageCard: View {
    let state: ModelUsageState?
    var body: some View {
        CardContainer(title: "Model Usage", status: CardStatus(from: state?.status)) {
            StatRow(label: "Sessions", value: "\(state?.totalSessions ?? 0)", color: .cyan)
            StatRow(label: "Tokens", value: formatNumber(state?.totalTokens ?? 0), color: .green)
            StatRow(label: "Cost", value: String(format: "$%.4f", state?.totalCostUsd ?? 0), color: .purple)
        }
    }
}

struct ConversationsCard: View {
    let state: ConversationState?
    var body: some View {
        CardContainer(title: "Conversations", status: (state?.activeCount ?? 0) > 0 ? .healthy : .unknown) {
            StatRow(label: "Active", value: "\(state?.activeCount ?? 0)", color: .cyan)
            if let channels = state?.byChannel {
                ForEach(Array(channels.sorted(by: { $0.value > $1.value })), id: \.key) { ch, count in
                    StatRow(label: ch.capitalized, value: "\(count)")
                }
            }
        }
    }
}

struct UnifiCard: View {
    let state: UnifiState?
    var body: some View {
        CardContainer(title: "UniFi Network", status: CardStatus(from: state?.status)) {
            StatRow(label: "Devices", value: "\(state?.deviceCount ?? 0)", color: .cyan)
            StatRow(label: "Clients", value: "\(state?.clientCount ?? 0)", color: .green)
            StatRow(label: "WAN Uptime", value: formatUptime(state?.wanUptimeS), color: .cyan)
        }
    }
}

struct ServicesCard: View {
    let services: [String: ServiceState]?
    var body: some View {
        CardContainer(title: "Services", status: .healthy) {
            if let svcs = services {
                ForEach(Array(svcs.sorted(by: { $0.key < $1.key })), id: \.key) { name, svc in
                    HStack {
                        Circle()
                            .fill(svc.status == "up" ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(name)
                            .font(.system(size: 16, design: .monospaced))
                        Spacer()
                        if let lat = svc.latencyMs {
                            Text("\(lat)ms")
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct AgentCard: View {
    let name: String
    let state: AgentState

    var body: some View {
        CardContainer(title: name.capitalized, status: CardStatus(from: state.status)) {
            StatRow(label: "Status", value: state.status ?? "?", color: state.status == "running" ? .green : .red)
            if let model = state.model, model != "unknown" {
                Text(model)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            StatRow(label: "Tasks", value: "\(state.tasksCompleted ?? 0)")
            StatRow(label: "Uptime", value: formatUptime(state.uptimeS))
        }
    }
}

func formatNumber(_ n: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
}
