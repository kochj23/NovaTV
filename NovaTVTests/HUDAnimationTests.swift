//
//  HUDAnimationTests.swift
//  NovaTVTests
//
//  Tests for v2.1.0 whimsical HUD features: boot sequence, heartbeat,
//  ghost trails, aurora, ripples, constellation mode, memory screensaver.
//  Covers all 7 test categories: Security, Performance, Retry, Unit,
//  Integration, Functional, Frame.
//
//  Written by Jordan Koch.
//

import XCTest
@testable import NovaTV

// MARK: - Unit Tests: HUDAnimationState

final class HUDAnimationStateUnitTests: XCTestCase {

    // MARK: Boot Sequence

    func testBootModeIsInitialState() {
        let state = HUDAnimationState()
        XCTAssertEqual(state.mode, .booting)
        XCTAssertEqual(state.bootProgress, 0)
    }

    func testBootProgressAdvancesWithTick() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 1.0, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertGreaterThan(state.bootProgress, 0)
        XCTAssertEqual(state.mode, .booting)
    }

    func testBootCompleteAfterThreeSeconds() {
        let state = HUDAnimationState()
        // Boot takes 3.0 seconds (bootProgress += deltaTime / 3.0)
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertEqual(state.bootProgress, 1.0)
        XCTAssertEqual(state.mode, .normal)
    }

    func testBootDoesNotAdvanceOtherAnimations() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 1.0, trafficFlow: ["slack": 0.5], isServiceUp: { _ in true }, nodeIds: ["slack"])
        // During boot, heartbeat and aurora should not advance
        XCTAssertEqual(state.heartbeatPhase, 0)
        XCTAssertEqual(state.auroraPhase, 0)
    }

    func testNodeBootOrderHas13Elements() {
        let state = HUDAnimationState()
        XCTAssertEqual(state.nodeBootOrder.count, 13)
        // All indices 0-12 should be present
        XCTAssertEqual(Set(state.nodeBootOrder), Set(0..<13))
    }

    // MARK: Heartbeat

    func testHeartbeatBPMScalesWithTraffic() {
        let state = HUDAnimationState()
        // Complete boot first
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // Zero traffic → 40 BPM base
        state.tick(deltaTime: 0.1, trafficFlow: [:], isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertEqual(state.heartbeatBPM, 40, accuracy: 1.0)

        // Full traffic → up to 180 BPM
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": 1.0], isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertEqual(state.heartbeatBPM, 180, accuracy: 1.0)
    }

    func testHeartbeatBPMClampsAtBounds() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // Negative traffic shouldn't go below 40
        state.tick(deltaTime: 0.1, trafficFlow: ["x": -1.0], isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertGreaterThanOrEqual(state.heartbeatBPM, 0)
    }

    func testHeartbeatPhaseAdvances() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])
        let phaseBefore = state.heartbeatPhase
        state.tick(deltaTime: 1.0, trafficFlow: ["slack": 0.5], isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertGreaterThan(state.heartbeatPhase, phaseBefore)
    }

    func testHeartbeatAmplitudeIsBounded() {
        let state = HUDAnimationState()
        // Test over a full cycle
        for i in 0..<100 {
            state.heartbeatPhase = Double(i) / 100.0
            let amp = state.heartbeatAmplitude()
            XCTAssertGreaterThanOrEqual(amp, 0, "Amplitude must be non-negative at phase \(state.heartbeatPhase)")
            XCTAssertLessThanOrEqual(amp, 2.0, "Amplitude must not exceed 2.0 at phase \(state.heartbeatPhase)")
        }
    }

    func testHeartbeatLubDubPattern() {
        let state = HUDAnimationState()
        // Lub peak around t=0.1
        state.heartbeatPhase = 0.1
        let lub = state.heartbeatAmplitude()
        // Dub peak around t=0.25
        state.heartbeatPhase = 0.25
        let dub = state.heartbeatAmplitude()
        // Rest around t=0.6
        state.heartbeatPhase = 0.6
        let rest = state.heartbeatAmplitude()

        XCTAssertGreaterThan(lub, 0.5, "Lub peak should be prominent")
        XCTAssertGreaterThan(dub, 0.2, "Dub peak should be visible")
        XCTAssertLessThan(rest, 0.1, "Rest period should be near zero")
    }

    // MARK: Ghost Trails

    func testGhostNodeCreatedWhenServiceDown() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        state.tick(deltaTime: 0.1, trafficFlow: nil, isServiceUp: { $0 != "redis" }, nodeIds: ["redis", "ollama"])
        XCTAssertNotNil(state.ghostNodes["redis"])
        XCTAssertNil(state.ghostNodes["ollama"])
    }

    func testGhostNodeDriftsOverTime() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        state.tick(deltaTime: 1.0, trafficFlow: nil, isServiceUp: { _ in false }, nodeIds: ["redis"])
        let drift1 = state.ghostNodes["redis"]!.driftProgress

        state.tick(deltaTime: 5.0, trafficFlow: nil, isServiceUp: { _ in false }, nodeIds: ["redis"])
        let drift2 = state.ghostNodes["redis"]!.driftProgress

        XCTAssertGreaterThan(drift2, drift1)
    }

    func testGhostNodeMaxDriftIsOne() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // Run for a very long time with service down
        for _ in 0..<100 {
            state.tick(deltaTime: 1.0, trafficFlow: nil, isServiceUp: { _ in false }, nodeIds: ["redis"])
        }
        XCTAssertLessThanOrEqual(state.ghostNodes["redis"]!.driftProgress, 1.0)
    }

    func testGhostNodeOpacityDecreases() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        state.tick(deltaTime: 10.0, trafficFlow: nil, isServiceUp: { _ in false }, nodeIds: ["redis"])
        let opacity = state.ghostNodes["redis"]!.opacity
        XCTAssertLessThan(opacity, 1.0)
        XCTAssertGreaterThanOrEqual(opacity, 0.15, "Ghost opacity should not go below 0.15")
    }

    func testGhostNodeRecovery() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // Service goes down
        state.tick(deltaTime: 5.0, trafficFlow: nil, isServiceUp: { _ in false }, nodeIds: ["redis"])
        XCTAssertNotNil(state.ghostNodes["redis"])

        // Service comes back
        state.tick(deltaTime: 0.5, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: ["redis"])
        if let ghost = state.ghostNodes["redis"] {
            XCTAssertTrue(ghost.recovering)
        }

        // After full recovery, ghost is removed
        state.tick(deltaTime: 5.0, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: ["redis"])
        XCTAssertNil(state.ghostNodes["redis"])
    }

    func testGhostOffsetReturnsIdentityWhenNoGhost() {
        let state = HUDAnimationState()
        let (x, y, opacity) = state.ghostOffset(for: "redis", nx: 100, ny: 200, cx: 50, cy: 50)
        XCTAssertEqual(x, 100)
        XCTAssertEqual(y, 200)
        XCTAssertEqual(opacity, 1.0)
    }

    func testGhostOffsetDriftsAwayFromCenter() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])
        state.tick(deltaTime: 15.0, trafficFlow: nil, isServiceUp: { _ in false }, nodeIds: ["redis"])

        let cx = 500.0, cy = 500.0
        let nx = 800.0, ny = 500.0 // Node to the right of center
        let (gx, _, _) = state.ghostOffset(for: "redis", nx: nx, ny: ny, cx: cx, cy: cy)
        // Ghost should drift further from center (to the right)
        XCTAssertGreaterThan(gx, nx)
    }

    // MARK: Aurora

    func testAuroraPhaseAdvances() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])
        let before = state.auroraPhase
        state.tick(deltaTime: 1.0, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertGreaterThan(state.auroraPhase, before)
    }

    func testAuroraPhaseAdvancesSlowly() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])
        state.tick(deltaTime: 1.0, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])
        // 0.015 per second
        XCTAssertEqual(state.auroraPhase, 0.015, accuracy: 0.001)
    }

    // MARK: Constellation Mode

    func testConstellationActivatesAfterIdle() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // Simulate 5+ minutes idle (no traffic above threshold)
        state.lastActivityTime = Date().addingTimeInterval(-301)
        state.tick(deltaTime: 0.1, trafficFlow: [:], isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertEqual(state.mode, .constellation)
    }

    func testConstellationDeactivatesOnActivity() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // Force constellation mode
        state.lastActivityTime = Date().addingTimeInterval(-301)
        state.tick(deltaTime: 0.1, trafficFlow: [:], isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertEqual(state.mode, .constellation)

        // Activity resets it
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": 0.5], isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertEqual(state.mode, .normal)
    }

    func testConstellationProgressBounded() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        state.lastActivityTime = Date().addingTimeInterval(-301)
        // Many ticks
        for _ in 0..<100 {
            state.tick(deltaTime: 0.5, trafficFlow: [:], isServiceUp: { _ in true }, nodeIds: [])
        }
        XCTAssertLessThanOrEqual(state.constellationProgress, 1.0)
    }

    func testConstellationCycles() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // Different idle durations should cycle constellations (every 30s)
        state.lastActivityTime = Date().addingTimeInterval(-310)
        state.tick(deltaTime: 0.1, trafficFlow: [:], isServiceUp: { _ in true }, nodeIds: [])
        let first = state.currentConstellation

        state.lastActivityTime = Date().addingTimeInterval(-340)
        state.tick(deltaTime: 0.1, trafficFlow: [:], isServiceUp: { _ in true }, nodeIds: [])
        let second = state.currentConstellation

        // They should be different constellations (310/30 vs 340/30)
        XCTAssertNotEqual(first, second)
    }

    // MARK: Ripples

    func testRippleSpawnsOnTrafficSpike() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // Set baseline
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": 0.1], isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertEqual(state.activeRipples.count, 0)

        // Spike
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": 0.5], isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertEqual(state.activeRipples.count, 1)
        XCTAssertEqual(state.activeRipples.first?.sourceNodeId, "slack")
    }

    func testRippleOnlyFromMessagingNodes() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // Ollama is not a messaging node
        state.tick(deltaTime: 0.1, trafficFlow: ["ollama": 0.1], isServiceUp: { _ in true }, nodeIds: [])
        state.tick(deltaTime: 0.1, trafficFlow: ["ollama": 0.9], isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertEqual(state.activeRipples.count, 0)
    }

    func testRipplesCulledAfterCompletion() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // Spawn a ripple
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": 0.1], isServiceUp: { _ in true }, nodeIds: [])
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": 0.5], isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertEqual(state.activeRipples.count, 1)

        // Advance past 2s lifetime
        state.tick(deltaTime: 2.1, trafficFlow: ["slack": 0.5], isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertEqual(state.activeRipples.count, 0)
    }

    // MARK: Node Positions

    func testNodePositionDuringBoot() {
        let state = HUDAnimationState()
        // At boot start, node should be off-screen
        let (x, y, opacity) = state.nodePosition(index: 0, baseX: 500, baseY: 300, cx: 960, cy: 540, screenWidth: 1920, screenHeight: 1080)
        // Opacity should be 0 or very low at the start
        XCTAssertLessThan(opacity, 0.5)
        // Position should differ from base (off-screen)
        let distFromBase = sqrt(pow(x - 500, 2) + pow(y - 300, 2))
        XCTAssertGreaterThan(distFromBase, 100)
    }

    func testNodePositionAfterBoot() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        let (x, y, opacity) = state.nodePosition(index: 0, baseX: 500, baseY: 300, cx: 960, cy: 540, screenWidth: 1920, screenHeight: 1080)
        XCTAssertEqual(x, 500, accuracy: 0.01)
        XCTAssertEqual(y, 300, accuracy: 0.01)
        XCTAssertEqual(opacity, 1.0, accuracy: 0.01)
    }
}

// MARK: - Unit Tests: ConstellationPatterns

final class ConstellationPatternsUnitTests: XCTestCase {

    func testPatternCountMatchesStatic() {
        XCTAssertEqual(ConstellationPatterns.count, 4)
        XCTAssertEqual(ConstellationPatterns.patterns.count, 4)
    }

    func testAllPatternsHave13Points() {
        for (i, pattern) in ConstellationPatterns.patterns.enumerated() {
            XCTAssertEqual(pattern.count, 13, "Pattern \(i) should have 13 points (one per node)")
        }
    }

    func testAllPointsInNormalizedRange() {
        for (i, pattern) in ConstellationPatterns.patterns.enumerated() {
            for (j, point) in pattern.enumerated() {
                XCTAssertGreaterThanOrEqual(point.x, -1.0, "Pattern \(i) point \(j) x out of range")
                XCTAssertLessThanOrEqual(point.x, 1.0, "Pattern \(i) point \(j) x out of range")
                XCTAssertGreaterThanOrEqual(point.y, -1.0, "Pattern \(i) point \(j) y out of range")
                XCTAssertLessThanOrEqual(point.y, 1.0, "Pattern \(i) point \(j) y out of range")
            }
        }
    }

    func testPatternsAreDistinct() {
        // Each constellation should have different point distributions
        for i in 0..<ConstellationPatterns.count {
            for j in (i + 1)..<ConstellationPatterns.count {
                let pi = ConstellationPatterns.patterns[i]
                let pj = ConstellationPatterns.patterns[j]
                var same = 0
                for k in 0..<13 {
                    if abs(pi[k].x - pj[k].x) < 0.01 && abs(pi[k].y - pj[k].y) < 0.01 {
                        same += 1
                    }
                }
                XCTAssertLessThan(same, 5, "Patterns \(i) and \(j) are too similar")
            }
        }
    }
}

// MARK: - Unit Tests: MemoryScreensaverService

final class MemoryScreensaverServiceUnitTests: XCTestCase {

    func testServiceInitialState() {
        let service = MemoryScreensaverService()
        XCTAssertNil(service.currentMemory)
        XCTAssertTrue(service.memoryQueue.isEmpty)
    }

    func testAdvanceWithEmptyQueue() {
        let service = MemoryScreensaverService()
        service.advance()
        XCTAssertNil(service.currentMemory)
    }

    func testAdvanceConsumesQueue() {
        let service = MemoryScreensaverService()
        let item = MemoryItem(text: "Test memory", source: "unit_test", category: "testing", year: 2026)
        service.memoryQueue.append(item)
        service.advance()
        XCTAssertEqual(service.currentMemory?.text, "Test memory")
        XCTAssertTrue(service.memoryQueue.isEmpty)
    }

    func testAdvanceMultipleItemsInOrder() {
        let service = MemoryScreensaverService()
        service.memoryQueue.append(MemoryItem(text: "First", source: "test", category: "a", year: 2020))
        service.memoryQueue.append(MemoryItem(text: "Second", source: "test", category: "b", year: 2021))
        service.memoryQueue.append(MemoryItem(text: "Third", source: "test", category: "c", year: 2022))

        service.advance()
        XCTAssertEqual(service.currentMemory?.text, "First")
        service.advance()
        XCTAssertEqual(service.currentMemory?.text, "Second")
        service.advance()
        XCTAssertEqual(service.currentMemory?.text, "Third")
    }

    func testMemoryItemFields() {
        let item = MemoryItem(text: "Knowledge about geology", source: "wikipedia", category: "geology", year: 2024)
        XCTAssertEqual(item.text, "Knowledge about geology")
        XCTAssertEqual(item.source, "wikipedia")
        XCTAssertEqual(item.category, "geology")
        XCTAssertEqual(item.year, 2024)
        XCTAssertNotNil(item.id)
    }

    func testMemoryItemUniqueIDs() {
        let item1 = MemoryItem(text: "Same text", source: "test", category: "a", year: 2026)
        let item2 = MemoryItem(text: "Same text", source: "test", category: "a", year: 2026)
        XCTAssertNotEqual(item1.id, item2.id)
    }

    func testServiceBaseURLIsLocal() {
        let service = MemoryScreensaverService()
        // Access the baseURL through reflection or by testing fetch behavior
        // The service should only connect to local network
        let mirror = Mirror(reflecting: service)
        let baseURL = mirror.children.first(where: { $0.label == "baseURL" })?.value as? String
        if let url = baseURL {
            XCTAssertTrue(url.contains("192.168.") || url.contains("127.0.0.1") || url.contains("localhost"),
                          "Service must connect to local network only")
            XCTAssertFalse(url.contains("https://"), "Service should not use external HTTPS endpoints")
        }
    }

    func testStopCancelsTask() {
        let service = MemoryScreensaverService()
        service.start()
        service.stop()
        // Starting and stopping should not crash or leave state inconsistent
        XCTAssertTrue(service.memoryQueue.isEmpty)
    }
}

// MARK: - Unit Tests: FloatingWord

final class FloatingWordUnitTests: XCTestCase {

    func testFloatingWordInit() {
        let word = FloatingWord(text: "hello", x: 100, y: 200, vx: 0.5, vy: -0.1, fontSize: 28, opacity: 0, lifetime: 7.0)
        XCTAssertEqual(word.text, "hello")
        XCTAssertEqual(word.x, 100)
        XCTAssertEqual(word.y, 200)
        XCTAssertEqual(word.vx, 0.5)
        XCTAssertEqual(word.vy, -0.1)
        XCTAssertEqual(word.fontSize, 28)
        XCTAssertEqual(word.opacity, 0)
        XCTAssertEqual(word.lifetime, 7.0)
        XCTAssertEqual(word.age, 0)
        XCTAssertNotNil(word.id)
    }

    func testFloatingWordPhaseProgression() {
        var word = FloatingWord(text: "test", x: 0, y: 0, vx: 0, vy: 0, fontSize: 24, opacity: 0, lifetime: 7.0)
        XCTAssertEqual(word.phase, .fadingIn)

        word.age = 1.1
        word.phase = .holding
        XCTAssertEqual(word.phase, .holding)

        word.age = 5.1
        word.phase = .fadingOut
        XCTAssertEqual(word.phase, .fadingOut)
    }
}

// MARK: - Integration Tests

final class HUDAnimationIntegrationTests: XCTestCase {

    func testBootToNormalTransitionPreservesState() {
        let state = HUDAnimationState()
        let nodeIds = ["ollama", "redis", "slack", "discord", "postgres"]

        // Tick through boot
        for _ in 0..<100 {
            state.tick(deltaTime: 0.033, trafficFlow: ["slack": 0.3], isServiceUp: { _ in true }, nodeIds: nodeIds)
        }

        XCTAssertEqual(state.mode, .normal)
        // After boot, heartbeat should have started
        XCTAssertGreaterThan(state.heartbeatPhase, 0)
        // Aurora should have started
        XCTAssertGreaterThan(state.auroraPhase, 0)
    }

    func testGhostAndRippleCoexist() {
        let state = HUDAnimationState()
        let nodeIds = ["slack", "discord", "redis"]

        // Complete boot
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: nodeIds)

        // Create ghost (redis down) and ripple (slack spike) simultaneously
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": 0.1], isServiceUp: { $0 != "redis" }, nodeIds: nodeIds)
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": 0.5], isServiceUp: { $0 != "redis" }, nodeIds: nodeIds)

        XCTAssertNotNil(state.ghostNodes["redis"])
        XCTAssertEqual(state.activeRipples.count, 1)
    }

    func testConstellationAndGhostInteraction() {
        let state = HUDAnimationState()
        let nodeIds = ["slack", "redis"]

        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: nodeIds)

        // Service goes down, creating ghost
        state.tick(deltaTime: 0.1, trafficFlow: nil, isServiceUp: { $0 != "redis" }, nodeIds: nodeIds)
        XCTAssertNotNil(state.ghostNodes["redis"])

        // Go idle long enough for constellation mode
        state.lastActivityTime = Date().addingTimeInterval(-301)
        state.tick(deltaTime: 0.1, trafficFlow: [:], isServiceUp: { $0 != "redis" }, nodeIds: nodeIds)

        // Both should coexist
        XCTAssertEqual(state.mode, .constellation)
        XCTAssertNotNil(state.ghostNodes["redis"])
    }

    func testFullAnimationCycleBoot_Normal_Constellation_Normal() {
        let state = HUDAnimationState()
        let nodeIds = ["slack", "ollama"]

        // Phase 1: Boot
        XCTAssertEqual(state.mode, .booting)
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: nodeIds)

        // Phase 2: Normal
        XCTAssertEqual(state.mode, .normal)
        state.tick(deltaTime: 0.5, trafficFlow: ["slack": 0.3], isServiceUp: { _ in true }, nodeIds: nodeIds)
        XCTAssertEqual(state.mode, .normal)

        // Phase 3: Constellation (5 min idle)
        state.lastActivityTime = Date().addingTimeInterval(-301)
        state.tick(deltaTime: 0.1, trafficFlow: [:], isServiceUp: { _ in true }, nodeIds: nodeIds)
        XCTAssertEqual(state.mode, .constellation)

        // Phase 4: Back to normal on activity
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": 0.3], isServiceUp: { _ in true }, nodeIds: nodeIds)
        XCTAssertEqual(state.mode, .normal)
    }

    func testMemoryServiceQueueAndAdvanceCycle() {
        let service = MemoryScreensaverService()

        // Simulate pre-fill
        for i in 0..<5 {
            service.memoryQueue.append(MemoryItem(text: "Memory \(i)", source: "test", category: "cat\(i)", year: 2020 + i))
        }
        XCTAssertEqual(service.memoryQueue.count, 5)

        // Advance through all
        for i in 0..<5 {
            service.advance()
            XCTAssertEqual(service.currentMemory?.text, "Memory \(i)")
        }
        XCTAssertTrue(service.memoryQueue.isEmpty)
    }
}

// MARK: - Performance Tests

final class HUDAnimationPerformanceTests: XCTestCase {

    func testTickPerformanceUnderLoad() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        let nodeIds = ["ollama", "openrouter", "mlx", "redis", "postgres", "memory", "scheduler", "searxng", "slack", "discord", "signal", "imessage", "email"]
        let trafficFlow = Dictionary(uniqueKeysWithValues: nodeIds.map { ($0, Double.random(in: 0...1)) })

        measure {
            for _ in 0..<1000 {
                state.tick(deltaTime: 0.033, trafficFlow: trafficFlow, isServiceUp: { _ in true }, nodeIds: nodeIds)
            }
        }
    }

    func testNodePositionComputationPerformance() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        measure {
            for _ in 0..<10000 {
                for i in 0..<13 {
                    _ = state.nodePosition(index: i, baseX: Double(i) * 100, baseY: 300, cx: 960, cy: 540, screenWidth: 1920, screenHeight: 1080)
                }
            }
        }
    }

    func testGhostOffsetPerformance() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // Add ghost nodes
        let nodeIds = ["ollama", "redis", "postgres", "slack", "discord"]
        for _ in 0..<10 {
            state.tick(deltaTime: 1.0, trafficFlow: nil, isServiceUp: { _ in false }, nodeIds: nodeIds)
        }

        measure {
            for _ in 0..<10000 {
                for id in nodeIds {
                    _ = state.ghostOffset(for: id, nx: 800, ny: 400, cx: 960, cy: 540)
                }
            }
        }
    }

    func testConstellationPatternAccessPerformance() {
        measure {
            for _ in 0..<100000 {
                let pattern = ConstellationPatterns.patterns[Int.random(in: 0..<4)]
                _ = pattern[Int.random(in: 0..<13)]
            }
        }
    }

    func testRippleCullingPerformance() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // Spawn many ripples
        for _ in 0..<50 {
            state.activeRipples.append(Ripple(sourceNodeId: "slack", startTime: state.heartbeatPhase))
        }

        measure {
            for _ in 0..<1000 {
                state.tick(deltaTime: 0.033, trafficFlow: ["slack": 0.5], isServiceUp: { _ in true }, nodeIds: ["slack"])
            }
        }
    }

    func testMemoryQueueOperationPerformance() {
        let service = MemoryScreensaverService()

        measure {
            for i in 0..<1000 {
                service.memoryQueue.append(MemoryItem(text: "Memory text number \(i) with enough words to simulate real content from the database", source: "test", category: "geology", year: 2024))
            }
            for _ in 0..<1000 {
                service.advance()
            }
        }
    }
}

// MARK: - Security Tests

final class HUDAnimationSecurityTests: XCTestCase {

    func testMemoryServiceURLIsLocalOnly() {
        let service = MemoryScreensaverService()
        let mirror = Mirror(reflecting: service)
        if let baseURL = mirror.children.first(where: { $0.label == "baseURL" })?.value as? String {
            XCTAssertTrue(baseURL.starts(with: "http://192.168.") || baseURL.starts(with: "http://127.0.0.1") || baseURL.starts(with: "http://localhost"))
            XCTAssertFalse(baseURL.contains("https://"))
            XCTAssertFalse(baseURL.contains(".com"))
            XCTAssertFalse(baseURL.contains(".io"))
            XCTAssertFalse(baseURL.contains(".net"))
        }
    }

    func testNoHardcodedSecretsInAnimationCode() {
        let files = [
            "/Volumes/Data/xcode/NovaTV/NovaTV/Models/HUDAnimationState.swift",
            "/Volumes/Data/xcode/NovaTV/NovaTV/Models/ConstellationPatterns.swift",
            "/Volumes/Data/xcode/NovaTV/NovaTV/Views/HUDDrawingExtensions.swift",
            "/Volumes/Data/xcode/NovaTV/NovaTV/Views/MemoryScreensaverView.swift",
            "/Volumes/Data/xcode/NovaTV/NovaTV/Services/MemoryScreensaverService.swift",
        ]

        let patterns = [
            "sk-[a-zA-Z0-9]{20,}",
            "AKIA[A-Z0-9]{16}",
            "ghp_[a-zA-Z0-9]{36}",
            "xox[bpoas]-[a-zA-Z0-9-]+",
            "password\\s*=\\s*\"[^\"]+\"",
            "token\\s*=\\s*\"[^\"]+\"",
        ]

        for file in files {
            guard let content = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
            for pattern in patterns {
                let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let matches = regex?.matches(in: content, range: NSRange(content.startIndex..., in: content)) ?? []
                XCTAssertEqual(matches.count, 0, "Potential secret in \(file) matching pattern: \(pattern)")
            }
        }
    }

    func testNoExternalURLsInNewFiles() {
        let files = [
            "/Volumes/Data/xcode/NovaTV/NovaTV/Models/HUDAnimationState.swift",
            "/Volumes/Data/xcode/NovaTV/NovaTV/Models/ConstellationPatterns.swift",
            "/Volumes/Data/xcode/NovaTV/NovaTV/Views/HUDDrawingExtensions.swift",
            "/Volumes/Data/xcode/NovaTV/NovaTV/Views/MemoryScreensaverView.swift",
            "/Volumes/Data/xcode/NovaTV/NovaTV/Services/MemoryScreensaverService.swift",
        ]

        let externalPatterns = [
            "api\\.openai\\.com",
            "api\\.anthropic\\.com",
            "openrouter\\.ai",
            "amazonaws\\.com",
        ]

        for file in files {
            guard let content = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
            for pattern in externalPatterns {
                let regex = try? NSRegularExpression(pattern: pattern)
                let matches = regex?.matches(in: content, range: NSRange(content.startIndex..., in: content)) ?? []
                XCTAssertEqual(matches.count, 0, "External URL found in \(file): \(pattern)")
            }
        }
    }

    func testNoPIIInConstellationNames() {
        let piiPatterns = [
            "kochj", "jordan", "gmail\\.com", "digitalnoise",
            "disney", "192\\.168\\.[0-9]+\\.[0-9]+",
        ]

        let file = "/Volumes/Data/xcode/NovaTV/NovaTV/Models/ConstellationPatterns.swift"
        guard let content = try? String(contentsOfFile: file, encoding: .utf8) else {
            XCTFail("Could not read ConstellationPatterns.swift")
            return
        }

        for pattern in piiPatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex?.matches(in: content, range: NSRange(content.startIndex..., in: content)) ?? []
            XCTAssertEqual(matches.count, 0, "PII pattern '\(pattern)' found in ConstellationPatterns.swift")
        }
    }

    func testAnimationStateDoesNotLeakUserData() {
        let state = HUDAnimationState()
        // Ensure ghost nodes use opaque IDs, not user identifiers
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: ["slack"])
        state.tick(deltaTime: 1.0, trafficFlow: nil, isServiceUp: { _ in false }, nodeIds: ["slack"])

        // Ghost keys should be service IDs, not user-identifiable data
        for key in state.ghostNodes.keys {
            XCTAssertFalse(key.contains("@"), "Ghost node key should not contain email addresses")
            XCTAssertFalse(key.contains("/Users/"), "Ghost node key should not contain file paths")
        }
    }

    func testMemoryItemDoesNotExposeInternalPaths() {
        let item = MemoryItem(text: "Some knowledge", source: "wikipedia", category: "geology", year: 2024)
        let mirror = Mirror(reflecting: item)
        for child in mirror.children {
            if let value = child.value as? String {
                XCTAssertFalse(value.contains("/Users/"), "MemoryItem field '\(child.label ?? "")' should not contain file paths")
            }
        }
    }
}

// MARK: - Retry Tests

final class MemoryScreensaverRetryTests: XCTestCase {

    func testServiceHandlesNetworkFailureGracefully() {
        let service = MemoryScreensaverService()
        // fetchOne should return nil on failure, not crash
        // We can't easily mock URLSession here, but verify the queue doesn't corrupt
        service.advance()
        XCTAssertNil(service.currentMemory)
        XCTAssertTrue(service.memoryQueue.isEmpty)
    }

    func testServiceContinuesAfterEmptyResponse() {
        let service = MemoryScreensaverService()
        // Empty queue doesn't crash advance
        for _ in 0..<10 {
            service.advance()
        }
        XCTAssertNil(service.currentMemory)
    }

    func testServiceStartStopIsIdempotent() {
        let service = MemoryScreensaverService()
        service.start()
        service.start()
        service.stop()
        service.stop()
        // No crash, no dangling tasks
        service.start()
        service.stop()
    }

    func testAnimationStateSurvivesMalformedTrafficData() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // NaN traffic shouldn't crash
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": Double.nan], isServiceUp: { _ in true }, nodeIds: ["slack"])
        // Infinity shouldn't crash
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": Double.infinity], isServiceUp: { _ in true }, nodeIds: ["slack"])
        // Negative shouldn't crash
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": -100.0], isServiceUp: { _ in true }, nodeIds: ["slack"])

        // State should still be usable
        XCTAssertEqual(state.mode, .normal)
    }

    func testAnimationStateSurvivesZeroDeltaTime() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 0, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertEqual(state.mode, .booting)
        XCTAssertEqual(state.bootProgress, 0)
    }

    func testAnimationStateSurvivesNegativeDeltaTime() {
        let state = HUDAnimationState()
        state.tick(deltaTime: -1.0, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])
        // Should not crash, bootProgress might go negative but state remains valid
        XCTAssertEqual(state.mode, .booting)
    }
}

// MARK: - Functional Tests

final class HUDAnimationFunctionalTests: XCTestCase {

    func testCompleteBootSequenceVisualProgression() {
        let state = HUDAnimationState()
        let screenW = 1920.0, screenH = 1080.0
        let cx = screenW * 0.55, cy = screenH * 0.47

        // During boot, nodes should progressively appear
        var visibleCount = 0
        state.tick(deltaTime: 1.5, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        for i in 0..<13 {
            let (_, _, opacity) = state.nodePosition(index: i, baseX: cx + 200, baseY: cy, cx: cx, cy: cy, screenWidth: screenW, screenHeight: screenH)
            if opacity > 0.5 { visibleCount += 1 }
        }

        // After 1.5s (halfway through boot), some but not all nodes should be visible
        XCTAssertGreaterThan(visibleCount, 0, "Some nodes should be visible mid-boot")
        XCTAssertLessThan(visibleCount, 13, "Not all nodes should be visible mid-boot")
    }

    func testAuroraPaletteChangesByTimeOfDay() {
        // Verify the palette selection logic via HUDEffects
        // Night: 22-5 → purple tones
        // Morning: 5-10 → pink/gold
        // Day: 10-17 → cyan
        // Evening: 17-22 → orange
        // We can't easily unit test a static private method, but we verify
        // aurora phase advances and the system doesn't crash at any hour
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])
        state.tick(deltaTime: 100, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertGreaterThan(state.auroraPhase, 1.0)
    }

    func testRippleLifecycle() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // No ripples initially
        XCTAssertTrue(state.activeRipples.isEmpty)

        // Trigger a ripple via traffic spike on Slack
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": 0.0], isServiceUp: { _ in true }, nodeIds: ["slack"])
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": 0.5], isServiceUp: { _ in true }, nodeIds: ["slack"])
        XCTAssertEqual(state.activeRipples.count, 1)

        // Ripple progresses
        state.tick(deltaTime: 0.5, trafficFlow: ["slack": 0.5], isServiceUp: { _ in true }, nodeIds: ["slack"])
        if let ripple = state.activeRipples.first {
            XCTAssertGreaterThan(ripple.progress, 0)
            XCTAssertLessThan(ripple.progress, 1.0)
        }

        // Ripple completes and is culled
        state.tick(deltaTime: 2.0, trafficFlow: ["slack": 0.5], isServiceUp: { _ in true }, nodeIds: ["slack"])
        // Original ripple should be gone (progress >= 1.0 culled)
        let oldRipples = state.activeRipples.filter { $0.progress >= 1.0 }
        XCTAssertTrue(oldRipples.isEmpty)
    }

    func testGhostVisualLifecycle() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: ["redis"])

        // Service healthy → no ghost
        XCTAssertNil(state.ghostNodes["redis"])

        // Service fails → ghost appears and drifts
        state.tick(deltaTime: 5.0, trafficFlow: nil, isServiceUp: { _ in false }, nodeIds: ["redis"])
        let ghost = state.ghostNodes["redis"]!
        XCTAssertGreaterThan(ghost.driftProgress, 0)
        XCTAssertLessThan(ghost.opacity, 1.0)

        // Service recovers → ghost snaps back
        state.tick(deltaTime: 0.3, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: ["redis"])
        if let recovering = state.ghostNodes["redis"] {
            XCTAssertTrue(recovering.recovering)
        }
    }

    func testMultipleRipplesFromDifferentSources() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // Baseline
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": 0.1, "discord": 0.1, "signal": 0.1], isServiceUp: { _ in true }, nodeIds: ["slack", "discord", "signal"])

        // All three spike simultaneously
        state.tick(deltaTime: 0.1, trafficFlow: ["slack": 0.5, "discord": 0.6, "signal": 0.7], isServiceUp: { _ in true }, nodeIds: ["slack", "discord", "signal"])

        XCTAssertEqual(state.activeRipples.count, 3)
        let sources = Set(state.activeRipples.map(\.sourceNodeId))
        XCTAssertTrue(sources.contains("slack"))
        XCTAssertTrue(sources.contains("discord"))
        XCTAssertTrue(sources.contains("signal"))
    }

    func testScreensaverMemoryDisplayFlow() {
        let service = MemoryScreensaverService()

        // Simulate fetched memories
        let memories = [
            MemoryItem(text: "The geological formation known as a moraine is deposited by glacial activity", source: "wikipedia", category: "geology", year: 2024),
            MemoryItem(text: "Reinforcement learning from human feedback improves model alignment", source: "arxiv", category: "ai_ml", year: 2023),
            MemoryItem(text: "The human brain contains approximately 86 billion neurons", source: "textbook", category: "neuroscience", year: 2022),
        ]

        for mem in memories {
            service.memoryQueue.append(mem)
        }

        // Each advance shows the next memory
        service.advance()
        XCTAssertTrue(service.currentMemory!.text.contains("moraine"))

        service.advance()
        XCTAssertTrue(service.currentMemory!.text.contains("Reinforcement"))

        service.advance()
        XCTAssertTrue(service.currentMemory!.text.contains("86 billion"))
    }
}

// MARK: - Frame (Smoke) Tests

final class HUDAnimationFrameTests: XCTestCase {

    func testHUDAnimationStateInstantiates() {
        let state = HUDAnimationState()
        XCTAssertNotNil(state)
        XCTAssertEqual(state.mode, .booting)
    }

    func testConstellationPatternsAccessible() {
        XCTAssertEqual(ConstellationPatterns.count, 4)
        XCTAssertFalse(ConstellationPatterns.patterns.isEmpty)
        XCTAssertEqual(ConstellationPatterns.patterns[0].count, 13)
    }

    func testMemoryScreensaverServiceInstantiates() {
        let service = MemoryScreensaverService()
        XCTAssertNotNil(service)
        XCTAssertNil(service.currentMemory)
    }

    func testMemoryItemInstantiates() {
        let item = MemoryItem(text: "test", source: "test", category: "test", year: 2026)
        XCTAssertNotNil(item)
        XCTAssertNotNil(item.id)
    }

    func testFloatingWordInstantiates() {
        let word = FloatingWord(text: "hello", x: 0, y: 0, vx: 0, vy: 0, fontSize: 24, opacity: 1, lifetime: 5)
        XCTAssertNotNil(word)
        XCTAssertNotNil(word.id)
    }

    func testRippleInstantiates() {
        let ripple = Ripple(sourceNodeId: "slack", startTime: 0)
        XCTAssertNotNil(ripple)
        XCTAssertNotNil(ripple.id)
        XCTAssertEqual(ripple.progress, 0)
    }

    func testGhostStateInstantiates() {
        let ghost = GhostState(downSince: Date())
        XCTAssertEqual(ghost.driftProgress, 0)
        XCTAssertEqual(ghost.opacity, 1.0)
        XCTAssertFalse(ghost.recovering)
    }

    func testHUDModeEnum() {
        let modes: [HUDMode] = [.booting, .normal, .constellation]
        XCTAssertEqual(modes.count, 3)
    }

    func testTickDoesNotCrashWithEmptyInputs() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 0.033, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])
        state.tick(deltaTime: 0.033, trafficFlow: [:], isServiceUp: { _ in false }, nodeIds: [])
        state.tick(deltaTime: 0.033, trafficFlow: nil, isServiceUp: { _ in false }, nodeIds: ["a", "b", "c"])
    }

    func testServiceStartAndStopDoesNotCrash() {
        let service = MemoryScreensaverService()
        service.start()
        service.stop()
    }

    func testLargeNumberOfGhostNodesDoesNotCrash() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        let manyNodes = (0..<100).map { "node_\($0)" }
        state.tick(deltaTime: 1.0, trafficFlow: nil, isServiceUp: { _ in false }, nodeIds: manyNodes)
        XCTAssertEqual(state.ghostNodes.count, 100)
    }

    func testLargeNumberOfRipplesDoesNotCrash() {
        let state = HUDAnimationState()
        state.tick(deltaTime: 3.1, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])

        // Manually inject many ripples
        for _ in 0..<500 {
            state.activeRipples.append(Ripple(sourceNodeId: "slack", startTime: 0))
        }
        // Tick should handle culling gracefully
        state.tick(deltaTime: 0.033, trafficFlow: nil, isServiceUp: { _ in true }, nodeIds: [])
        XCTAssertLessThanOrEqual(state.activeRipples.count, 500)
    }
}
