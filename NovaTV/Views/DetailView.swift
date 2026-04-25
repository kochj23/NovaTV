import SwiftUI

struct DetailView: View {
    let title: String
    let service: String
    @EnvironmentObject var dashboard: DashboardService
    @State private var detail: [String: Any]?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(40)
                        Spacer()
                    }
                } else if let detail {
                    detailContent(detail)
                } else {
                    Text("Failed to load details")
                        .font(.system(size: 22, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(40)
                }
            }
            .padding(60)
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .navigationTitle(title)
        .task {
            detail = await dashboard.fetchDetail(service: service)
            isLoading = false
        }
    }

    @ViewBuilder
    private func detailContent(_ data: [String: Any]) -> some View {
        let sorted = data.sorted { a, b in
            let order = ["status", "today", "yesterday", "this_week", "total", "db_size",
                         "memory_used", "redis_version", "uptime_seconds", "hit_rate",
                         "total_sessions", "total_cost_usd", "active_count",
                         "device_count", "client_count"]
            let ai = order.firstIndex(of: a.key) ?? 999
            let bi = order.firstIndex(of: b.key) ?? 999
            return ai < bi
        }

        ForEach(sorted, id: \.key) { key, value in
            if let dict = value as? [String: Any] {
                DetailSection(title: formatKey(key), data: dict)
            } else if let array = value as? [[String: Any]] {
                DetailArraySection(title: formatKey(key), items: array)
            } else if let array = value as? [String] {
                DetailStringArraySection(title: formatKey(key), items: array)
            } else {
                DetailRow(label: formatKey(key), value: formatValue(value))
            }
        }
    }
}

struct DetailSection: View {
    let title: String
    let data: [String: Any]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(.cyan)
                .padding(.top, 8)
            ForEach(data.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                if let nested = value as? [String: Any] {
                    ForEach(nested.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                        DetailRow(label: "\(formatKey(key)) → \(formatKey(k))", value: formatValue(v))
                    }
                } else {
                    DetailRow(label: formatKey(key), value: formatValue(value))
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct DetailArraySection: View {
    let title: String
    let items: [[String: Any]]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) (\(items.count))")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(.cyan)
                .padding(.top, 8)

            ForEach(Array(items.prefix(20).enumerated()), id: \.offset) { _, item in
                HStack(spacing: 16) {
                    ForEach(item.sorted(by: { $0.key < $1.key }).prefix(5), id: \.key) { key, value in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatKey(key))
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(formatValue(value))
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct DetailStringArraySection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) (\(items.count))")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(.cyan)
                .padding(.top, 8)
            ForEach(items.suffix(30), id: \.self) { line in
                Text(line)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var color: Color {
        if value == "ok" || value == "up" || value == "running" || value == "Connected" || value == "live" { return .green }
        if value == "down" || value == "error" || value == "stopped" { return .red }
        if value.hasSuffix("GB") || value.hasSuffix("MB") { return .purple }
        if value.hasPrefix("$") { return .purple }
        if value.hasSuffix("%") {
            if let n = Double(value.dropLast()), n > 90 { return .red }
            if let n = Double(value.dropLast()), n > 70 { return .yellow }
        }
        return .primary
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 18, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

private func formatKey(_ key: String) -> String {
    key.replacingOccurrences(of: "_", with: " ")
        .split(separator: " ")
        .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        .joined(separator: " ")
}

private func formatValue(_ value: Any) -> String {
    if let n = value as? Int {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    if let n = value as? Double {
        if n > 1_000_000 { return String(format: "%.1fM", n / 1_000_000) }
        if n > 1_000 { return String(format: "%.1fK", n / 1_000) }
        if n == n.rounded() { return String(format: "%.0f", n) }
        return String(format: "%.2f", n)
    }
    if let s = value as? String { return s }
    if let b = value as? Bool { return b ? "Yes" : "No" }
    return "\(value)"
}
