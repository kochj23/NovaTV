import Foundation

struct DashboardState: Codable {
    let ts: Double?
    let pollDurationMs: Int?
    let system: SystemState?
    let gateway: GatewayState?
    let scheduler: SchedulerState?
    let ollama: OllamaState?
    let postgresql: PostgresState?
    let redis: RedisState?
    let services: [String: ServiceState]?
    let agents: [String: AgentState]?
    let taskHistory: TaskHistoryState?
    let modelUsage: ModelUsageState?
    let conversations: ConversationState?
    let unifi: UnifiState?
    let alerts: [AlertItem]?
    let trafficFlow: [String: Double]?
    let journal: JournalSummaryState?
    let bigBrother: BigBrotherSummaryState?

    enum CodingKeys: String, CodingKey {
        case ts, system, gateway, scheduler, ollama, postgresql, redis, services, agents
        case taskHistory = "task_history"
        case modelUsage = "model_usage"
        case conversations, unifi, alerts
        case trafficFlow = "traffic_flow"
        case pollDurationMs = "poll_duration_ms"
        case journal
        case bigBrother = "big_brother"
    }
}

// MARK: - Journal

struct JournalSummaryState: Codable {
    let polledAt: String?
    let totals: JournalTotals?
    let traffic: JournalTraffic?
    let sectionViews: [String: Int]?
    let staleSections: [String]?
    let sections: [String: JournalSectionBrief]?
    let lastDeploy: JournalDeployBrief?

    enum CodingKeys: String, CodingKey {
        case polledAt = "polled_at"
        case totals, traffic
        case sectionViews  = "section_views"
        case staleSections = "stale_sections"
        case sections
        case lastDeploy = "last_deploy"
    }
}

struct JournalTotals: Codable {
    let posts: Int?
    let postsThisWeek: Int?
    let wordsThisWeek: Int?
    enum CodingKeys: String, CodingKey {
        case posts
        case postsThisWeek  = "posts_this_week"
        case wordsThisWeek  = "words_this_week"
    }
}

struct JournalTraffic: Codable {
    let totalCount: Int?
    let totalUniques: Int?
    enum CodingKeys: String, CodingKey {
        case totalCount   = "total_count"
        case totalUniques = "total_uniques"
    }
}

struct JournalSectionBrief: Codable {
    let ageHours: Double?
    let latestTitle: String?
    let postsThisWeek: Int?
    let postCount: Int?
    enum CodingKeys: String, CodingKey {
        case ageHours       = "age_hours"
        case latestTitle    = "latest_title"
        case postsThisWeek  = "posts_this_week"
        case postCount      = "post_count"
    }
}

struct JournalDeployBrief: Codable {
    let title: String?
    let conclusion: String?
    let createdAt: String?
    enum CodingKeys: String, CodingKey {
        case title, conclusion
        case createdAt = "created_at"
    }
}

// MARK: - Big Brother

struct BigBrotherSummaryState: Codable {
    let uptimeS: Int?
    let eventsTotal: Int?
    let servicesDown: [String]?
    let pendingRestarts: [String]?
    enum CodingKeys: String, CodingKey {
        case uptimeS        = "uptime_s"
        case eventsTotal    = "events_total"
        case servicesDown   = "services_down"
        case pendingRestarts = "pending_restarts"
    }
}

struct SystemState: Codable {
    let status: String?
    let cpuPercent: Double?
    let memory: MemoryInfo?
    let swap: SwapInfo?
    let disks: [String: DiskInfo]?
    let network: NetworkInfo?

    enum CodingKeys: String, CodingKey {
        case status, memory, swap, disks, network
        case cpuPercent = "cpu_percent"
    }
}

struct MemoryInfo: Codable {
    let totalGb: Double?
    let usedGb: Double?
    let availableGb: Double?
    let percent: Double?

    enum CodingKeys: String, CodingKey {
        case percent
        case totalGb = "total_gb"
        case usedGb = "used_gb"
        case availableGb = "available_gb"
    }
}

struct SwapInfo: Codable {
    let totalGb: Double?
    let usedGb: Double?
    let percent: Double?
    enum CodingKeys: String, CodingKey {
        case percent
        case totalGb = "total_gb"
        case usedGb = "used_gb"
    }
}

struct DiskInfo: Codable {
    let totalGb: Double?
    let usedGb: Double?
    let freeGb: Double?
    let percent: Double?
    enum CodingKeys: String, CodingKey {
        case percent
        case totalGb = "total_gb"
        case usedGb = "used_gb"
        case freeGb = "free_gb"
    }
}

struct NetworkInfo: Codable {
    let bytesSent: Int?
    let bytesRecv: Int?
    enum CodingKeys: String, CodingKey {
        case bytesSent = "bytes_sent"
        case bytesRecv = "bytes_recv"
    }
}

struct GatewayState: Codable {
    let status: String?
    let ok: Bool?
    let gatewayStatus: String?
    let wsReachable: Bool?
    enum CodingKeys: String, CodingKey {
        case status, ok
        case gatewayStatus = "gateway_status"
        case wsReachable = "ws_reachable"
    }
}

struct SchedulerState: Codable {
    let status: String?
    let info: SchedulerInfo?
    let runningTasks: [String]?
    let failedTasks: [String]?
    enum CodingKeys: String, CodingKey {
        case status, info
        case runningTasks = "running_tasks"
        case failedTasks = "failed_tasks"
    }
}

struct SchedulerInfo: Codable {
    let status: String?
    let uptimeS: Int?
    let tasksTotal: Int?
    let tasksRunning: Int?
    let totalRuns: Int?
    let totalFailures: Int?
    enum CodingKeys: String, CodingKey {
        case status
        case uptimeS = "uptime_s"
        case tasksTotal = "tasks_total"
        case tasksRunning = "tasks_running"
        case totalRuns = "total_runs"
        case totalFailures = "total_failures"
    }
}

struct OllamaState: Codable {
    let status: String?
    let models: [OllamaModel]?
    let totalVramGb: Double?
    let modelCount: Int?
    enum CodingKeys: String, CodingKey {
        case status, models
        case totalVramGb = "total_vram_gb"
        case modelCount = "model_count"
    }
}

struct OllamaModel: Codable {
    let name: String?
    let family: String?
    let params: String?
    let quant: String?
    let vramGb: Double?
    let contextLength: Int?
    enum CodingKeys: String, CodingKey {
        case name, family, params, quant
        case vramGb = "vram_gb"
        case contextLength = "context_length"
    }
}

struct PostgresState: Codable {
    let status: String?
    let dbSizeGb: Double?
    let totalRows: Int?
    let tables: [TableInfo]?
    let indexCount: Int?
    enum CodingKeys: String, CodingKey {
        case status, tables
        case dbSizeGb = "db_size_gb"
        case totalRows = "total_rows"
        case indexCount = "index_count"
    }
}

struct TableInfo: Codable {
    let name: String
    let rows: Int
}

struct RedisState: Codable {
    let status: String?
    let dbSize: Int?
    let ingestQueueDepth: Int?
    enum CodingKeys: String, CodingKey {
        case status
        case dbSize = "db_size"
        case ingestQueueDepth = "ingest_queue_depth"
    }
}

struct ServiceState: Codable {
    let status: String?
    let port: Int?
    let latencyMs: Int?
    enum CodingKeys: String, CodingKey {
        case status, port
        case latencyMs = "latency_ms"
    }
}

struct AgentState: Codable {
    let status: String?
    let model: String?
    let tasksCompleted: Int?
    let uptimeS: Int?
    let lastError: String?
    enum CodingKeys: String, CodingKey {
        case status, model
        case tasksCompleted = "tasks_completed"
        case uptimeS = "uptime_s"
        case lastError = "last_error"
    }
}

struct TaskHistoryState: Codable {
    let status: String?
    let allTime: [String: Int]?
    let last24h: [String: Int]?
    enum CodingKeys: String, CodingKey {
        case status
        case allTime = "all_time"
        case last24h = "last_24h"
    }
}

struct ModelUsageState: Codable {
    let status: String?
    let totalSessions: Int?
    let totalCostUsd: Double?
    let totalTokens: Int?
    let byProvider: [String: ProviderUsage]?
    enum CodingKeys: String, CodingKey {
        case status
        case totalSessions = "total_sessions"
        case totalCostUsd = "total_cost_usd"
        case totalTokens = "total_tokens"
        case byProvider = "by_provider"
    }
}

struct ProviderUsage: Codable {
    let sessions: Int?
    let inputTokens: Int?
    let outputTokens: Int?
    let cost: Double?
    enum CodingKeys: String, CodingKey {
        case sessions, cost
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

struct ConversationState: Codable {
    let status: String?
    let activeCount: Int?
    let byChannel: [String: Int]?
    enum CodingKeys: String, CodingKey {
        case status
        case activeCount = "active_count"
        case byChannel = "by_channel"
    }
}

struct UnifiState: Codable {
    let status: String?
    let deviceCount: Int?
    let clientCount: Int?
    let wanUptimeS: Int?
    enum CodingKeys: String, CodingKey {
        case status
        case deviceCount = "device_count"
        case clientCount = "client_count"
        case wanUptimeS = "wan_uptime_s"
    }
}

struct AlertItem: Codable {
    let category: String
    let severity: String
    let message: String
}
