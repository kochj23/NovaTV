// VoiceCommandParser.swift
// NovaTV — Enterprise Feature #3: Siri Remote Voice Commands
//
// Long-press Siri button triggers voice input. This parser maps recognized
// phrases to navigation actions and TTS status queries.
//
// Written by Jordan Koch.

import Foundation
import Speech
import AVFoundation

@MainActor
final class VoiceCommandParser: ObservableObject {
    @Published var isListening = false
    @Published var lastCommand: String?
    @Published var lastResult: VoiceCommandResult?

    private let synthesizer = AVSpeechSynthesizer()

    /// Navigation commands: maps phrases to page indices
    private let navigationMap: [String: Int] = [
        "show hud": 0,
        "show dashboard": 1,
        "show journal": 2,
        "show big brother": 3,
        "show trends": 4,
        "go to hud": 0,
        "go to dashboard": 1,
        "go to journal": 2,
        "go to big brother": 3,
        "go to trends": 4,
        "open hud": 0,
        "open dashboard": 1,
        "open journal": 2,
        "open trends": 4,
    ]

    /// Service-specific navigation queries
    private let serviceQueries: [String: String] = [
        "show postgresql": "postgresql",
        "show postgres": "postgresql",
        "show redis": "redis",
        "show ollama": "ollama",
        "show gateway": "gateway",
        "show scheduler": "scheduler",
        "show system": "system",
        "show services": "services",
        "show network": "unifi",
        "show unifi": "unifi",
    ]

    /// Status query patterns
    private let statusPatterns: [(pattern: String, handler: (DashboardState) -> String)] = [
        ("how is the scheduler", { state in
            guard let s = state.scheduler?.info else { return "Scheduler status unavailable" }
            let rate = (s.totalRuns ?? 0) > 0 ? Double((s.totalRuns ?? 0) - (s.totalFailures ?? 0)) / Double(s.totalRuns ?? 1) * 100 : 100
            return "Scheduler is \(s.status ?? "unknown") with \(s.tasksTotal ?? 0) tasks. Success rate is \(String(format: "%.1f", rate)) percent. Uptime is \(formatHours(s.uptimeS ?? 0))"
        }),
        ("how is the gateway", { state in
            let ok = state.gateway?.ok ?? false
            return ok ? "Gateway is online and healthy" : "Gateway is offline or unreachable"
        }),
        ("how is memory", { state in
            guard let sys = state.system?.memory else { return "Memory info unavailable" }
            return "Memory usage is \(Int(sys.percent ?? 0)) percent. \(String(format: "%.1f", sys.availableGb ?? 0)) gigabytes available out of \(String(format: "%.0f", sys.totalGb ?? 0))"
        }),
        ("how is postgres", { state in
            guard let pg = state.postgresql else { return "PostgreSQL status unavailable" }
            return "PostgreSQL is \(pg.status ?? "unknown"). Database size is \(String(format: "%.1f", pg.dbSizeGb ?? 0)) gigabytes with \(formatCount(pg.totalRows ?? 0)) rows"
        }),
        ("what is the cpu", { state in
            let cpu = state.system?.cpuPercent ?? 0
            return "CPU usage is \(Int(cpu)) percent"
        }),
        ("system status", { state in
            let cpu = state.system?.cpuPercent ?? 0
            let mem = state.system?.memory?.percent ?? 0
            let gwOk = state.gateway?.ok ?? false
            return "System CPU at \(Int(cpu)) percent, memory at \(Int(mem)) percent. Gateway is \(gwOk ? "online" : "offline")"
        }),
        ("are there any alerts", { state in
            guard let alerts = state.alerts, !alerts.isEmpty else {
                return "No active alerts. All systems nominal."
            }
            let critical = alerts.filter { $0.severity == "critical" }.count
            let warnings = alerts.filter { $0.severity == "warning" }.count
            return "\(alerts.count) active alerts: \(critical) critical, \(warnings) warnings. Latest: \(alerts.first?.message ?? "")"
        }),
    ]

    enum VoiceCommandResult {
        case navigate(page: Int)
        case navigateService(service: String)
        case speak(text: String)
        case unrecognized
    }

    /// Parse a voice command string and return the action
    func parse(command: String, state: DashboardState?) -> VoiceCommandResult {
        let normalized = command.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        lastCommand = normalized

        // Check navigation commands
        for (phrase, page) in navigationMap {
            if normalized.contains(phrase) {
                lastResult = .navigate(page: page)
                return .navigate(page: page)
            }
        }

        // Check service-specific navigation
        for (phrase, service) in serviceQueries {
            if normalized.contains(phrase) {
                lastResult = .navigateService(service: service)
                return .navigateService(service: service)
            }
        }

        // Check status queries
        if let state {
            for (pattern, handler) in statusPatterns {
                if normalized.contains(pattern) {
                    let response = handler(state)
                    lastResult = .speak(text: response)
                    speak(response)
                    return .speak(text: response)
                }
            }
        }

        lastResult = .unrecognized
        speak("Command not recognized")
        return .unrecognized
    }

    /// Use TTS to speak a response
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

// MARK: - Helpers

private func formatHours(_ seconds: Int) -> String {
    let hours = seconds / 3600
    if hours > 24 {
        return "\(hours / 24) days, \(hours % 24) hours"
    }
    return "\(hours) hours"
}

private func formatCount(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.2f million", Double(n) / 1_000_000) }
    if n >= 1_000 { return String(format: "%.1f thousand", Double(n) / 1_000) }
    return "\(n)"
}
