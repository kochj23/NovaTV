import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dashboard: DashboardService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerBar
                    alertBanner
                    statusGrid
                    agentGrid
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 40)
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        }
    }

    private var headerBar: some View {
        HStack {
            Text("NOVA CONTROL")
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.cyan)
                .shadow(color: .cyan.opacity(0.3), radius: 10)
            Spacer()
            HStack(spacing: 16) {
                if let poll = dashboard.state?.pollDurationMs {
                    Text("poll: \(poll)ms")
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Circle()
                    .fill(dashboard.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                    .shadow(color: dashboard.isConnected ? .green.opacity(0.5) : .red.opacity(0.5), radius: 6)
            }
        }
        .padding(.vertical, 30)
    }

    @ViewBuilder
    private var alertBanner: some View {
        if let alerts = dashboard.state?.alerts, !alerts.isEmpty {
            VStack(spacing: 8) {
                ForEach(Array(alerts.enumerated()), id: \.offset) { _, alert in
                    HStack(spacing: 12) {
                        Text(alert.severity.uppercased())
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(alert.severity == "critical" ? Color.red : Color.yellow)
                            .frame(width: 100, alignment: .leading)
                        Text(alert.message)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
            .background(Color.red.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.3), lineWidth: 1))
            .padding(.bottom, 20)
        }
    }

    private var statusGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 20),
            GridItem(.flexible(), spacing: 20),
            GridItem(.flexible(), spacing: 20),
        ], spacing: 20) {
            SystemCard(state: dashboard.state?.system)
            GatewayCard(state: dashboard.state?.gateway)
            SchedulerCard(state: dashboard.state?.scheduler)
            OllamaCard(state: dashboard.state?.ollama)
            PostgresCard(state: dashboard.state?.postgresql)
            RedisCard(state: dashboard.state?.redis)
            TaskHistoryCard(state: dashboard.state?.taskHistory)
            ModelUsageCard(state: dashboard.state?.modelUsage)
            ConversationsCard(state: dashboard.state?.conversations)
            UnifiCard(state: dashboard.state?.unifi)
            ServicesCard(services: dashboard.state?.services)
        }
        .padding(.bottom, 20)
    }

    private var agentGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AGENTS")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20),
            ], spacing: 20) {
                if let agents = dashboard.state?.agents {
                    ForEach(Array(agents.sorted(by: { $0.key < $1.key })), id: \.key) { name, agent in
                        AgentCard(name: name, state: agent)
                    }
                }
            }
        }
    }
}
