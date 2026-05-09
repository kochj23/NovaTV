// JournalAndBBViews.swift
// NovaTV — Journal Dashboard + Big Brother Dashboard for Apple TV
//
// Written by Jordan Koch.

import SwiftUI

// MARK: - Shared helpers

private let SECTION_ICONS: [String: String] = [
    "dreams": "🌙", "essays": "📝", "opinions": "💬",
    "after-dark": "🌃", "tech-today": "💻", "research": "📄", "digests": "📋"
]
private let SECTION_ORDER = ["dreams", "essays", "opinions", "after-dark", "tech-today", "research", "digests"]
private let STALE_THRESHOLD: [String: Double] = [
    "dreams": 26, "essays": 26, "opinions": 26, "after-dark": 26,
    "tech-today": 26, "research": 50, "digests": 26
]

private func ageText(_ h: Double?) -> String {
    guard let h, h < 9000 else { return "never" }
    if h < 1   { return "\(Int(h * 60))m ago" }
    if h < 24  { return String(format: "%.1fh ago", h) }
    return "\(Int(h / 24))d ago"
}

private func ageColor(_ h: Double?, section: String) -> Color {
    guard let h else { return .secondary }
    let threshold = STALE_THRESHOLD[section] ?? 26
    if h > threshold         { return .red }
    if h > threshold * 0.75  { return .yellow }
    return .green
}

private func fmtK(_ n: Int?) -> String {
    guard let n else { return "—" }
    if n >= 1000 { return String(format: "%.1fK", Double(n) / 1000) }
    return "\(n)"
}

private func uptimeText(_ s: Int?) -> String {
    guard let s else { return "—" }
    let h = s / 3600, m = (s % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
}

// MARK: - Journal Summary Card (for main dashboard grid)

struct JournalCard: View {
    let state: JournalSummaryState?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("JOURNAL")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.cyan)
                Spacer()
                if let stale = state?.staleSections, !stale.isEmpty {
                    Text("\(stale.count) STALE")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                } else {
                    Text("ALL CURRENT")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 24) {
                statItem(label: "POSTS", value: fmtK(state?.totals?.posts))
                statItem(label: "THIS WEEK", value: "\(state?.totals?.postsThisWeek ?? 0)")
                statItem(label: "VIEWS (14d)", value: fmtK(state?.traffic?.totalCount))
                statItem(label: "UNIQUES", value: fmtK(state?.traffic?.totalUniques))
            }

            // Section staleness strip
            HStack(spacing: 8) {
                ForEach(SECTION_ORDER, id: \.self) { section in
                    let brief = state?.sections?[section]
                    let age = brief?.ageHours
                    let color = ageColor(age, section: section)
                    VStack(spacing: 4) {
                        Text(SECTION_ICONS[section] ?? "•")
                            .font(.system(size: 20))
                        Text(ageText(age))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(color)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.2), lineWidth: 1))
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Big Brother Summary Card (for main dashboard grid)

struct BigBrotherCard: View {
    let state: BigBrotherSummaryState?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("BIG BROTHER")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.cyan)
                Spacer()
                let down = state?.servicesDown ?? []
                if down.isEmpty {
                    Text("ALL SYSTEMS OK")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.green)
                } else {
                    Text("\(down.count) DOWN")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                }
            }

            HStack(spacing: 24) {
                statItem(label: "UPTIME", value: uptimeText(state?.uptimeS))
                statItem(label: "HEAL EVENTS", value: fmtK(state?.eventsTotal))
                statItem(label: "PENDING", value: "\(state?.pendingRestarts?.count ?? 0)")
            }

            if let down = state?.servicesDown, !down.isEmpty {
                Text("DOWN: " + down.joined(separator: ", "))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(20)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            (state?.servicesDown?.isEmpty == false) ? Color.red.opacity(0.4) : Color.cyan.opacity(0.2),
            lineWidth: 1
        ))
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Full Journal Dashboard View (drill-down from main grid)

struct JournalDashboardView: View {
    @EnvironmentObject var dashboard: DashboardService
    @State private var fullStats: [String: Any]? = nil
    @State private var isLoading = true

    var journal: JournalSummaryState? { dashboard.state?.journal }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                if isLoading {
                    ProgressView()
                        .padding(60)
                } else {
                    statsRow
                    sectionHealthGrid
                    coverageHeatmap
                    bottomRow
                }
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 40)
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .task { await loadFullStats() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("JOURNAL DASHBOARD")
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .shadow(color: .cyan.opacity(0.3), radius: 10)
                Text("nova.digitalnoise.net · publishing pipeline & analytics")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let stale = journal?.staleSections, !stale.isEmpty {
                Label("\(stale.count) stale sections", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(.red)
            } else {
                Label("All sections current", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 30)
    }

    private var statsRow: some View {
        HStack(spacing: 32) {
            bigStat("TOTAL POSTS",     value: fmtK(journal?.totals?.posts))
            bigStat("THIS WEEK",       value: "\(journal?.totals?.postsThisWeek ?? 0)")
            bigStat("WORDS / WEEK",    value: journal?.totals?.wordsThisWeek.map { String(format: "%.1fK", Double($0)/1000) } ?? "—")
            bigStat("VIEWS (14d)",     value: fmtK(journal?.traffic?.totalCount))
            bigStat("UNIQUE VISITORS", value: fmtK(journal?.traffic?.totalUniques))
        }
        .padding(.bottom, 30)
    }

    private var sectionHealthGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SECTION HEALTH")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 4), spacing: 16) {
                ForEach(SECTION_ORDER, id: \.self) { section in
                    if let brief = journal?.sections?[section] {
                        sectionHealthCard(section: section, brief: brief)
                    }
                }
            }
        }
        .padding(.bottom, 30)
    }

    private func sectionHealthCard(section: String, brief: JournalSectionBrief) -> some View {
        let age = brief.ageHours
        let threshold = STALE_THRESHOLD[section] ?? 26
        let isStale = (age ?? 9999) > threshold
        let color = ageColor(age, section: section)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text((SECTION_ICONS[section] ?? "") + " " + section)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                Circle().fill(color).frame(width: 10, height: 10)
            }
            Text(ageText(age))
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(color)
            Text(brief.latestTitle ?? "—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 12) {
                Text("\(brief.postCount ?? 0) total")
                Text("\(brief.postsThisWeek ?? 0) this wk")
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(isStale ? Color.red.opacity(0.08) : Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 1))
    }

    private var coverageHeatmap: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("7-DAY COVERAGE")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            let days: [String] = (0..<7).map { i -> String in
                let d = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
                let f = DateFormatter(); f.dateFormat = "EEE d"
                return f.string(from: d)
            }

            // Header row
            HStack(spacing: 0) {
                Text("").frame(width: 120, alignment: .leading)
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(SECTION_ORDER, id: \.self) { section in
                HStack(spacing: 0) {
                    Text((SECTION_ICONS[section] ?? "") + " " + section)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .leading)
                    // Coverage booleans come from full stats if loaded
                    ForEach(0..<7, id: \.self) { i in
                        let covered = (fullStats?["sections"] as? [String: Any])?[section]
                            .flatMap { ($0 as? [String: Any])?["coverage_7d"] as? [Bool] }
                            .map { i < $0.count ? $0[i] : false } ?? false
                        RoundedRectangle(cornerRadius: 4)
                            .fill(covered ? Color.green.opacity(0.4) : Color.red.opacity(0.2))
                            .overlay(
                                Text(covered ? "✓" : "✗")
                                    .font(.system(size: 11))
                                    .foregroundStyle(covered ? .green : Color.red.opacity(0.6))
                            )
                            .frame(height: 28)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.bottom, 30)
    }

    private var bottomRow: some View {
        HStack(alignment: .top, spacing: 20) {
            // Last deploy
            VStack(alignment: .leading, spacing: 10) {
                Text("LAST DEPLOY")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let d = journal?.lastDeploy {
                    let ok = d.conclusion == "success"
                    Label(d.title ?? "—", systemImage: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(ok ? .green : .red)
                        .lineLimit(2)
                    if let ts = d.createdAt {
                        Text(String(ts.prefix(16)).replacingOccurrences(of: "T", with: " "))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(white: 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Section views breakdown
            VStack(alignment: .leading, spacing: 10) {
                Text("VIEWS BY SECTION")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                let views = journal?.sectionViews ?? [:]
                let maxV = views.values.max() ?? 1
                ForEach(SECTION_ORDER.filter { (views[$0] ?? 0) > 0 }, id: \.self) { s in
                    let count = views[s] ?? 0
                    HStack(spacing: 8) {
                        Text((SECTION_ICONS[s] ?? "") + " " + s)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.cyan.opacity(0.4))
                                .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxV))
                        }
                        .frame(height: 8)
                        Text("\(count)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(white: 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func bigStat(_ label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func loadFullStats() async {
        guard let url = URL(string: "\(dashboard.baseURL)/api/journal/stats") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            fullStats = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {}
        isLoading = false
    }
}

// MARK: - Full Big Brother Dashboard View (drill-down)

struct BigBrotherDashboardView: View {
    @EnvironmentObject var dashboard: DashboardService
    @State private var fullHealth: [String: Any]? = nil
    @State private var isLoading = true

    var bb: BigBrotherSummaryState? { dashboard.state?.bigBrother }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                if isLoading {
                    ProgressView().padding(60)
                } else {
                    statsRow
                    servicesGrid
                    eventFeed
                }
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 40)
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .task { await loadFullHealth() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("BIG BROTHER")
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .shadow(color: .cyan.opacity(0.3), radius: 10)
                Text("nova oversight & self-healing enforcer")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            let down = bb?.servicesDown ?? []
            if down.isEmpty {
                Label("All systems nominal", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            } else {
                Label("\(down.count) service(s) down", systemImage: "exclamationmark.shield.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.system(size: 18, design: .monospaced))
        .padding(.vertical, 30)
    }

    private var statsRow: some View {
        HStack(spacing: 32) {
            bbStat("UPTIME",       uptimeText(bb?.uptimeS))
            bbStat("HEAL EVENTS",  fmtK(bb?.eventsTotal))
            bbStat("DOWN NOW",     "\(bb?.servicesDown?.count ?? 0)")
            bbStat("PENDING",      "\(bb?.pendingRestarts?.count ?? 0)")
        }
        .padding(.bottom, 30)
    }

    private var servicesGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SERVICE STATUS")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            let services = (fullHealth?["services"] as? [String: Any]) ?? [:]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 5), spacing: 12) {
                ForEach(services.keys.sorted(), id: \.self) { name in
                    if let svc = services[name] as? [String: Any] {
                        let up = svc["up"] as? Bool ?? true
                        let restarts = svc["restarts"] as? Int ?? 0
                        VStack(spacing: 6) {
                            Circle().fill(up ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                                .shadow(color: (up ? Color.green : Color.red).opacity(0.6), radius: 6)
                            Text(name)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(up ? .white : .red)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            if restarts > 0 {
                                Text("\(restarts)↺")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(up ? Color(white: 0.07) : Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                            up ? Color(white: 0.15) : Color.red.opacity(0.4), lineWidth: 1
                        ))
                    }
                }
            }
        }
        .padding(.bottom, 30)
    }

    private var eventFeed: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RECENT HEAL EVENTS")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            let events = (fullHealth?["recent_events"] as? [[String: Any]]) ?? []
            ForEach(Array(events.prefix(8).enumerated()), id: \.offset) { _, ev in
                HStack(alignment: .top, spacing: 16) {
                    let sev = ev["severity"] as? String ?? "info"
                    Text(sev.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(sev == "critical" ? .red : sev == "warning" ? .yellow : .cyan)
                        .frame(width: 70, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ev["issue"] as? String ?? "")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("↳ " + (ev["fix"] as? String ?? ""))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String((ev["ts"] as? String ?? "").prefix(16)).replacingOccurrences(of: "T", with: " "))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                Divider().background(Color(white: 0.15))
            }
            if events.isEmpty {
                Text("No heal events — all systems nominal")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.green)
            }
        }
    }

    private func bbStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func loadFullHealth() async {
        guard let url = URL(string: "\(dashboard.baseURL)/api/bb/health") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            fullHealth = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {}
        isLoading = false
    }
}
