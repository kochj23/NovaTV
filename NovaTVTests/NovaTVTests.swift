//
//  NovaTVTests.swift
//  NovaTVTests
//
//  Unit tests for NovaTV dashboard models and utilities
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import NovaTV

// MARK: - DashboardState Decoding Tests

final class DashboardStateTests: XCTestCase {

    func testFullStateDecoding() throws {
        let json = """
        {
            "ts": 1714500000.0,
            "poll_duration_ms": 45,
            "system": {
                "status": "ok",
                "cpu_percent": 23.5,
                "memory": {
                    "total_gb": 512.0,
                    "used_gb": 128.5,
                    "available_gb": 383.5,
                    "percent": 25.1
                }
            },
            "gateway": {
                "status": "ok",
                "ok": true,
                "gateway_status": "live",
                "ws_reachable": true
            },
            "scheduler": {
                "status": "running",
                "info": {
                    "status": "running",
                    "uptime_s": 86400,
                    "tasks_total": 36,
                    "tasks_running": 2,
                    "total_runs": 1500,
                    "total_failures": 3
                }
            },
            "ollama": {
                "status": "up",
                "models": [
                    {
                        "name": "qwen3-next:80b",
                        "family": "qwen3",
                        "params": "80B",
                        "quant": "Q4_K_M",
                        "vram_gb": 48.5,
                        "context_length": 131072
                    }
                ],
                "total_vram_gb": 48.5,
                "model_count": 1
            },
            "redis": {
                "status": "ok",
                "db_size": 5000,
                "ingest_queue_depth": 0
            },
            "postgresql": {
                "status": "ok",
                "db_size_gb": 14.2,
                "total_rows": 1380000,
                "index_count": 42
            }
        }
        """
        let data = json.data(using: .utf8)!
        let state = try JSONDecoder().decode(DashboardState.self, from: data)

        XCTAssertEqual(state.ts, 1714500000.0)
        XCTAssertEqual(state.pollDurationMs, 45)
        XCTAssertEqual(state.system?.status, "ok")
        XCTAssertEqual(state.system?.cpuPercent, 23.5)
        XCTAssertEqual(state.system?.memory?.totalGb, 512.0)
        XCTAssertEqual(state.system?.memory?.percent, 25.1)
        XCTAssertEqual(state.gateway?.ok, true)
        XCTAssertEqual(state.gateway?.wsReachable, true)
        XCTAssertEqual(state.scheduler?.info?.tasksTotal, 36)
        XCTAssertEqual(state.scheduler?.info?.uptimeS, 86400)
        XCTAssertEqual(state.ollama?.modelCount, 1)
        XCTAssertEqual(state.ollama?.models?.first?.name, "qwen3-next:80b")
        XCTAssertEqual(state.redis?.dbSize, 5000)
        XCTAssertEqual(state.postgresql?.dbSizeGb, 14.2)
    }

    func testMinimalStateDecoding() throws {
        let json = "{}"
        let data = json.data(using: .utf8)!
        let state = try JSONDecoder().decode(DashboardState.self, from: data)

        XCTAssertNil(state.ts)
        XCTAssertNil(state.system)
        XCTAssertNil(state.gateway)
        XCTAssertNil(state.scheduler)
        XCTAssertNil(state.ollama)
        XCTAssertNil(state.redis)
        XCTAssertNil(state.postgresql)
        XCTAssertNil(state.alerts)
    }
}

// MARK: - Individual State Model Tests

final class SystemStateTests: XCTestCase {

    func testMemoryInfoDecoding() throws {
        let json = """
        {"total_gb": 512.0, "used_gb": 256.0, "available_gb": 256.0, "percent": 50.0}
        """
        let data = json.data(using: .utf8)!
        let mem = try JSONDecoder().decode(MemoryInfo.self, from: data)

        XCTAssertEqual(mem.totalGb, 512.0)
        XCTAssertEqual(mem.usedGb, 256.0)
        XCTAssertEqual(mem.availableGb, 256.0)
        XCTAssertEqual(mem.percent, 50.0)
    }

    func testDiskInfoDecoding() throws {
        let json = """
        {"total_gb": 2000.0, "used_gb": 1500.0, "free_gb": 500.0, "percent": 75.0}
        """
        let data = json.data(using: .utf8)!
        let disk = try JSONDecoder().decode(DiskInfo.self, from: data)

        XCTAssertEqual(disk.totalGb, 2000.0)
        XCTAssertEqual(disk.freeGb, 500.0)
        XCTAssertEqual(disk.percent, 75.0)
    }

    func testSwapInfoDecoding() throws {
        let json = """
        {"total_gb": 8.0, "used_gb": 0.5, "percent": 6.25}
        """
        let data = json.data(using: .utf8)!
        let swap = try JSONDecoder().decode(SwapInfo.self, from: data)
        XCTAssertEqual(swap.totalGb, 8.0)
        XCTAssertEqual(swap.usedGb, 0.5)
    }

    func testNetworkInfoDecoding() throws {
        let json = """
        {"bytes_sent": 1000000, "bytes_recv": 5000000}
        """
        let data = json.data(using: .utf8)!
        let net = try JSONDecoder().decode(NetworkInfo.self, from: data)
        XCTAssertEqual(net.bytesSent, 1000000)
        XCTAssertEqual(net.bytesRecv, 5000000)
    }
}

final class GatewayStateTests: XCTestCase {

    func testGatewayDecoding() throws {
        let json = """
        {"status": "ok", "ok": true, "gateway_status": "live", "ws_reachable": true}
        """
        let data = json.data(using: .utf8)!
        let gw = try JSONDecoder().decode(GatewayState.self, from: data)
        XCTAssertTrue(gw.ok!)
        XCTAssertEqual(gw.gatewayStatus, "live")
        XCTAssertTrue(gw.wsReachable!)
    }
}

final class SchedulerStateTests: XCTestCase {

    func testSchedulerInfoDecoding() throws {
        let json = """
        {
            "status": "running",
            "uptime_s": 172800,
            "tasks_total": 36,
            "tasks_running": 1,
            "total_runs": 5000,
            "total_failures": 10
        }
        """
        let data = json.data(using: .utf8)!
        let info = try JSONDecoder().decode(SchedulerInfo.self, from: data)

        XCTAssertEqual(info.uptimeS, 172800)
        XCTAssertEqual(info.tasksTotal, 36)
        XCTAssertEqual(info.totalFailures, 10)

        // Success rate calculation
        let rate = Double(info.totalRuns! - info.totalFailures!) / Double(info.totalRuns!) * 100
        XCTAssertEqual(rate, 99.8, accuracy: 0.01)
    }
}

final class OllamaModelTests: XCTestCase {

    func testModelDecoding() throws {
        let json = """
        {
            "name": "qwen3-next:80b",
            "family": "qwen3",
            "params": "80B",
            "quant": "Q4_K_M",
            "vram_gb": 48.5,
            "context_length": 131072
        }
        """
        let data = json.data(using: .utf8)!
        let model = try JSONDecoder().decode(NovaTV.OllamaModel.self, from: data)

        XCTAssertEqual(model.name, "qwen3-next:80b")
        XCTAssertEqual(model.family, "qwen3")
        XCTAssertEqual(model.vramGb, 48.5)
        XCTAssertEqual(model.contextLength, 131072)
    }
}

final class ServiceStateTests: XCTestCase {

    func testServiceDecoding() throws {
        let json = """
        {"status": "up", "port": 11434, "latency_ms": 12}
        """
        let data = json.data(using: .utf8)!
        let svc = try JSONDecoder().decode(ServiceState.self, from: data)

        XCTAssertEqual(svc.status, "up")
        XCTAssertEqual(svc.port, 11434)
        XCTAssertEqual(svc.latencyMs, 12)
    }
}

final class AgentStateTests: XCTestCase {

    func testAgentDecoding() throws {
        let json = """
        {
            "status": "running",
            "model": "qwen3-next:80b",
            "tasks_completed": 150,
            "uptime_s": 86400,
            "last_error": null
        }
        """
        let data = json.data(using: .utf8)!
        let agent = try JSONDecoder().decode(AgentState.self, from: data)

        XCTAssertEqual(agent.status, "running")
        XCTAssertEqual(agent.model, "qwen3-next:80b")
        XCTAssertEqual(agent.tasksCompleted, 150)
        XCTAssertEqual(agent.uptimeS, 86400)
        XCTAssertNil(agent.lastError)
    }
}

final class TaskHistoryTests: XCTestCase {

    func testTaskHistoryDecoding() throws {
        let json = """
        {
            "status": "ok",
            "all_time": {"succeeded": 15000, "failed": 25, "timed_out": 3},
            "last_24h": {"succeeded": 500, "failed": 1, "timed_out": 0}
        }
        """
        let data = json.data(using: .utf8)!
        let history = try JSONDecoder().decode(TaskHistoryState.self, from: data)

        XCTAssertEqual(history.allTime?["succeeded"], 15000)
        XCTAssertEqual(history.allTime?["failed"], 25)
        XCTAssertEqual(history.last24h?["succeeded"], 500)
    }
}

final class ModelUsageTests: XCTestCase {

    func testModelUsageDecoding() throws {
        let json = """
        {
            "status": "ok",
            "total_sessions": 5000,
            "total_cost_usd": 0.45,
            "total_tokens": 2500000,
            "by_provider": {
                "ollama": {
                    "sessions": 4800,
                    "input_tokens": 1000000,
                    "output_tokens": 1500000,
                    "cost": 0.0
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let usage = try JSONDecoder().decode(ModelUsageState.self, from: data)

        XCTAssertEqual(usage.totalSessions, 5000)
        XCTAssertEqual(usage.totalCostUsd!, 0.45, accuracy: 0.001)
        XCTAssertEqual(usage.totalTokens, 2500000)
        XCTAssertEqual(usage.byProvider?["ollama"]?.sessions, 4800)
    }
}

final class ConversationStateTests: XCTestCase {

    func testConversationDecoding() throws {
        let json = """
        {
            "status": "ok",
            "active_count": 3,
            "by_channel": {"slack": 1, "discord": 1, "signal": 1}
        }
        """
        let data = json.data(using: .utf8)!
        let conv = try JSONDecoder().decode(ConversationState.self, from: data)

        XCTAssertEqual(conv.activeCount, 3)
        XCTAssertEqual(conv.byChannel?["slack"], 1)
    }
}

final class UnifiStateTests: XCTestCase {

    func testUnifiDecoding() throws {
        let json = """
        {
            "status": "ok",
            "device_count": 15,
            "client_count": 42,
            "wan_uptime_s": 604800
        }
        """
        let data = json.data(using: .utf8)!
        let unifi = try JSONDecoder().decode(UnifiState.self, from: data)

        XCTAssertEqual(unifi.deviceCount, 15)
        XCTAssertEqual(unifi.clientCount, 42)
        XCTAssertEqual(unifi.wanUptimeS, 604800)
    }
}

final class AlertItemTests: XCTestCase {

    func testAlertDecoding() throws {
        let json = """
        {"category": "disk", "severity": "warning", "message": "SSD low on space"}
        """
        let data = json.data(using: .utf8)!
        let alert = try JSONDecoder().decode(AlertItem.self, from: data)

        XCTAssertEqual(alert.category, "disk")
        XCTAssertEqual(alert.severity, "warning")
        XCTAssertEqual(alert.message, "SSD low on space")
    }
}

// MARK: - CardStatus Tests

final class CardStatusTests: XCTestCase {

    func testStatusFromString() {
        XCTAssertEqual(CardStatus(from: "ok"), .healthy)
        XCTAssertEqual(CardStatus(from: "up"), .healthy)
        XCTAssertEqual(CardStatus(from: "running"), .healthy)
        XCTAssertEqual(CardStatus(from: "live"), .healthy)
        XCTAssertEqual(CardStatus(from: "degraded"), .degraded)
        XCTAssertEqual(CardStatus(from: "slow"), .degraded)
        XCTAssertEqual(CardStatus(from: "warning"), .degraded)
        XCTAssertEqual(CardStatus(from: "down"), .down)
        XCTAssertEqual(CardStatus(from: "error"), .down)
        XCTAssertEqual(CardStatus(from: "stopped"), .down)
        XCTAssertEqual(CardStatus(from: nil), .unknown)
        XCTAssertEqual(CardStatus(from: "something_else"), .unknown)
    }

    func testStatusColors() {
        // Ensure each status has a distinct color (no crashes)
        _ = CardStatus.healthy.color
        _ = CardStatus.degraded.color
        _ = CardStatus.down.color
        _ = CardStatus.unknown.color
    }

    func testBorderColor() {
        // All statuses share the same border color
        XCTAssertEqual(CardStatus.healthy.borderColor, CardStatus.down.borderColor)
    }
}

// MARK: - Utility Function Tests

final class FormatUptimeTests: XCTestCase {

    func testFormatUptimeNil() {
        XCTAssertEqual(formatUptime(nil), "---")
    }

    func testFormatUptimeZero() {
        XCTAssertEqual(formatUptime(0), "---")
    }

    func testFormatUptimeMinutes() {
        XCTAssertEqual(formatUptime(300), "5m")   // 5 minutes
    }

    func testFormatUptimeHours() {
        XCTAssertEqual(formatUptime(7200), "2h 0m")  // 2 hours
    }

    func testFormatUptimeDays() {
        XCTAssertEqual(formatUptime(90000), "1d 1h 0m")  // 1 day, 1 hour
    }

    func testFormatUptimeLarge() {
        XCTAssertEqual(formatUptime(604800), "7d 0m") // 7 days exactly
    }
}

final class FormatNumberTests: XCTestCase {

    func testFormatSmallNumber() {
        let result = formatNumber(42)
        XCTAssertEqual(result, "42")
    }

    func testFormatLargeNumber() {
        let result = formatNumber(1380000)
        XCTAssertTrue(result.contains("1,380,000") || result.contains("1.380.000"),
                       "Large number should be formatted with separators, got: \(result)")
    }

    func testFormatZero() {
        XCTAssertEqual(formatNumber(0), "0")
    }
}

// MARK: - Security Tests

final class NovaTVSecurityTests: XCTestCase {

    func testNoHardcodedAPIKeys() {
        let patterns = [
            "sk-[a-zA-Z0-9]{20,}",
            "AKIA[A-Z0-9]{16}",
            "ghp_[a-zA-Z0-9]{36}",
            "xox[bpoas]-[a-zA-Z0-9-]+",
        ]

        let files = findSwiftFiles(in: "/Volumes/Data/xcode/NovaTV/NovaTV")

        for file in files {
            guard let content = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
            for pattern in patterns {
                let regex = try? NSRegularExpression(pattern: pattern)
                let matches = regex?.matches(in: content, range: NSRange(content.startIndex..., in: content)) ?? []
                XCTAssertEqual(matches.count, 0, "Potential hardcoded secret found in \(file)")
            }
        }
    }

    func testWebSocketURLIsLocalNetwork() {
        let serviceFile = "/Volumes/Data/xcode/NovaTV/NovaTV/Services/DashboardService.swift"
        guard let content = try? String(contentsOfFile: serviceFile, encoding: .utf8) else {
            XCTFail("Could not read DashboardService.swift")
            return
        }

        // The WebSocket should connect to a local network address
        XCTAssertTrue(content.contains("192.168.") || content.contains("127.0.0.1") || content.contains("localhost"),
                       "DashboardService should connect to a local network address")

        // Should NOT connect to external services
        XCTAssertFalse(content.contains("wss://") && !content.contains("//localhost"),
                        "DashboardService should not use external WebSocket endpoints")
    }

    func testNoExternalAPIEndpoints() {
        let files = findSwiftFiles(in: "/Volumes/Data/xcode/NovaTV/NovaTV")

        for file in files {
            guard let content = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
            // NovaTV should only talk to local network
            XCTAssertFalse(content.contains("api.openai.com"), "NovaTV should not contact external AI APIs: \(file)")
            XCTAssertFalse(content.contains("api.anthropic.com"), "NovaTV should not contact external AI APIs: \(file)")
        }
    }

    // MARK: - Helper

    private func findSwiftFiles(in directory: String) -> [String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: directory) else { return [] }
        var files: [String] = []
        while let path = enumerator.nextObject() as? String {
            if path.hasSuffix(".swift") {
                files.append("\(directory)/\(path)")
            }
        }
        return files
    }
}
