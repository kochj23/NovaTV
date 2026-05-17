// TrendsView.swift
// NovaTV — Enterprise Feature #1: Sparkline Metrics with historical data
//
// Written by Jordan Koch.

import SwiftUI

/// 5th pager page — shows sparkline trend charts from the last 720 state snapshots
/// buffered in DashboardService.metricsHistory (circular buffer).
struct TrendsView: View {
    @EnvironmentObject var dashboard: DashboardService

    private let cyanColor = Color(red: 0, green: 1, blue: 0.78)
    private let greenColor = Color(red: 0, green: 1, blue: 0.4)
    private let amberColor = Color(red: 1, green: 0.8, blue: 0)
    private let redColor = Color(red: 1, green: 0.2, blue: 0.27)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                metricsGrid
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 40)
        }
        .background(Color(red: 0.02, green: 0.04, blue: 0.12))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TRENDS")
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .foregroundStyle(cyanColor)
                    .shadow(color: cyanColor.opacity(0.3), radius: 10)
                Text("last \(dashboard.metricsHistory.count) snapshots · \(formattedDuration)")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(dashboard.isConnected ? greenColor : redColor)
                .frame(width: 12, height: 12)
                .shadow(color: (dashboard.isConnected ? greenColor : redColor).opacity(0.5), radius: 6)
        }
        .padding(.vertical, 30)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 20),
            GridItem(.flexible(), spacing: 20),
        ], spacing: 20) {
            sparklineCard(
                title: "CPU USAGE",
                values: dashboard.metricsHistory.cpuValues(last: 120),
                unit: "%",
                thresholdWarn: 50,
                thresholdCrit: 80,
                color: cyanColor
            )
            sparklineCard(
                title: "MEMORY USAGE",
                values: dashboard.metricsHistory.memoryValues(last: 120),
                unit: "%",
                thresholdWarn: 70,
                thresholdCrit: 85,
                color: Color.purple
            )
            sparklineCard(
                title: "SCHEDULER SUCCESS",
                values: dashboard.metricsHistory.schedulerValues(last: 120),
                unit: "%",
                thresholdWarn: 95,
                thresholdCrit: 90,
                color: greenColor,
                invertThreshold: true
            )
            sparklineCard(
                title: "REDIS QUEUE DEPTH",
                values: dashboard.metricsHistory.redisQueueValues(last: 120),
                unit: "",
                thresholdWarn: 20,
                thresholdCrit: 50,
                color: amberColor
            )
            sparklineCard(
                title: "ACTIVE AGENTS",
                values: dashboard.metricsHistory.agentValues(last: 120),
                unit: "",
                thresholdWarn: -1,
                thresholdCrit: -1,
                color: cyanColor
            )
            summaryCard
        }
    }

    private func sparklineCard(title: String, values: [Double], unit: String, thresholdWarn: Double, thresholdCrit: Double, color: Color, invertThreshold: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                if let last = values.last {
                    let displayVal = unit == "%" ? String(format: "%.1f%@", last, unit) : String(format: "%.0f%@", last, unit)
                    let valColor: Color = {
                        if thresholdCrit < 0 { return color }
                        if invertThreshold {
                            if last < thresholdCrit { return redColor }
                            if last < thresholdWarn { return amberColor }
                            return greenColor
                        } else {
                            if last >= thresholdCrit { return redColor }
                            if last >= thresholdWarn { return amberColor }
                            return greenColor
                        }
                    }()
                    Text(displayVal)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(valColor)
                } else {
                    Text("---")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            // Sparkline chart
            SparklineView(values: values, color: color, thresholdWarn: thresholdWarn, thresholdCrit: thresholdCrit, invertThreshold: invertThreshold)
                .frame(height: 80)

            // Min / Max / Avg
            if !values.isEmpty {
                HStack(spacing: 16) {
                    miniStat("MIN", String(format: "%.1f", values.min() ?? 0))
                    miniStat("AVG", String(format: "%.1f", values.reduce(0, +) / Double(values.count)))
                    miniStat("MAX", String(format: "%.1f", values.max() ?? 0))
                }
            }
        }
        .padding(20)
        .background(Color(white: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BUFFER STATUS")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                statRow("Capacity", "\(dashboard.metricsHistory.capacity)")
                statRow("Filled", "\(dashboard.metricsHistory.count)")
                statRow("Fill %", String(format: "%.0f%%", Double(dashboard.metricsHistory.count) / Double(dashboard.metricsHistory.capacity) * 100))
                statRow("Connection", dashboard.isConnected ? "LIVE" : "DISCONNECTED")
            }

            Spacer()
        }
        .padding(20)
        .background(Color(white: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(cyanColor.opacity(0.2), lineWidth: 1))
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(cyanColor.opacity(0.8))
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(cyanColor)
        }
    }

    private var formattedDuration: String {
        let count = dashboard.metricsHistory.count
        if count == 0 { return "no data" }
        let seconds = count  // 1 snapshot/sec
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

// MARK: - SparklineView

struct SparklineView: View {
    let values: [Double]
    let color: Color
    let thresholdWarn: Double
    let thresholdCrit: Double
    var invertThreshold: Bool = false

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }

            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 1
            let range = max(maxVal - minVal, 0.001) // avoid division by zero

            let stepX = size.width / Double(values.count - 1)
            let padding: Double = 4

            // Build path
            var path = Path()
            for (i, val) in values.enumerated() {
                let x = Double(i) * stepX
                let normalized = (val - minVal) / range
                let y = size.height - padding - normalized * (size.height - padding * 2)

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            // Gradient fill below line
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(color.opacity(0.08)))

            // Stroke the line
            context.stroke(path, with: .color(color.opacity(0.7)), lineWidth: 1.5)

            // Threshold lines
            if thresholdWarn >= 0 {
                let warnY = size.height - padding - ((thresholdWarn - minVal) / range) * (size.height - padding * 2)
                if warnY > 0 && warnY < size.height {
                    context.stroke(
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: warnY))
                            p.addLine(to: CGPoint(x: size.width, y: warnY))
                        },
                        with: .color(Color.yellow.opacity(0.3)),
                        style: StrokeStyle(lineWidth: 0.5, dash: [4, 4])
                    )
                }
            }
            if thresholdCrit >= 0 {
                let critY = size.height - padding - ((thresholdCrit - minVal) / range) * (size.height - padding * 2)
                if critY > 0 && critY < size.height {
                    context.stroke(
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: critY))
                            p.addLine(to: CGPoint(x: size.width, y: critY))
                        },
                        with: .color(Color.red.opacity(0.3)),
                        style: StrokeStyle(lineWidth: 0.5, dash: [4, 4])
                    )
                }
            }

            // Latest value dot
            if let lastVal = values.last {
                let lastX = size.width
                let lastNorm = (lastVal - minVal) / range
                let lastY = size.height - padding - lastNorm * (size.height - padding * 2)
                context.fill(
                    Path { p in p.addArc(center: CGPoint(x: lastX, y: lastY), radius: 4, startAngle: .zero, endAngle: .degrees(360), clockwise: false) },
                    with: .color(color)
                )
            }
        }
    }
}
