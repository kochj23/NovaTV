import SwiftUI

enum HUDMode {
    case booting, normal, constellation
}

struct GhostState {
    var downSince: Date
    var driftProgress: Double = 0
    var opacity: Double = 1.0
    var recovering: Bool = false
}

struct Ripple: Identifiable {
    let id = UUID()
    let sourceNodeId: String
    let startTime: Double
    var progress: Double = 0
}

@Observable
final class HUDAnimationState {
    var mode: HUDMode = .booting
    var bootProgress: Double = 0
    var nodeBootOrder: [Int] = (0..<13).shuffled()

    var constellationProgress: Double = 0
    var currentConstellation: Int = 0
    var lastActivityTime: Date = Date()
    private let constellationIdleThreshold: TimeInterval = 300

    var heartbeatPhase: Double = 0
    var heartbeatBPM: Double = 60

    var ghostNodes: [String: GhostState] = [:]

    var auroraPhase: Double = 0

    var activeRipples: [Ripple] = []
    var previousTrafficFlow: [String: Double] = [:]

    func tick(deltaTime: Double, trafficFlow: [String: Double]?, isServiceUp: (String) -> Bool, nodeIds: [String]) {
        // Boot sequence
        if mode == .booting {
            bootProgress += deltaTime / 3.0
            if bootProgress >= 1.0 {
                bootProgress = 1.0
                mode = .normal
            }
            return
        }

        // Heartbeat BPM from total traffic
        let totalTraffic = trafficFlow?.values.reduce(0, +) ?? 0
        heartbeatBPM = 40 + totalTraffic * 140  // 40-180 BPM
        let beatsPerSecond = heartbeatBPM / 60.0
        heartbeatPhase += deltaTime * beatsPerSecond

        // Aurora slow drift
        auroraPhase += deltaTime * 0.015

        // Detect activity for constellation mode
        if let tf = trafficFlow, tf.values.contains(where: { $0 > 0.05 }) {
            lastActivityTime = Date()
        }

        // Constellation mode transitions
        let idleTime = Date().timeIntervalSince(lastActivityTime)
        if mode == .normal && idleTime > constellationIdleThreshold {
            mode = .constellation
        } else if mode == .constellation && idleTime < 2.0 {
            mode = .normal
        }

        if mode == .constellation {
            constellationProgress = min(1.0, constellationProgress + deltaTime * 0.3)
            // Cycle constellations every 30s
            if Int(idleTime / 30) % ConstellationPatterns.count != currentConstellation {
                currentConstellation = Int(idleTime / 30) % ConstellationPatterns.count
                constellationProgress = 0
            }
        } else {
            constellationProgress = max(0, constellationProgress - deltaTime * 2.0)
        }

        // Ghost trails
        for nodeId in nodeIds {
            let isUp = isServiceUp(nodeId)
            if !isUp {
                if ghostNodes[nodeId] == nil {
                    ghostNodes[nodeId] = GhostState(downSince: Date())
                }
                if var ghost = ghostNodes[nodeId], !ghost.recovering {
                    ghost.driftProgress = min(1.0, ghost.driftProgress + deltaTime / 30.0)
                    ghost.opacity = max(0.15, 1.0 - ghost.driftProgress * 0.85)
                    ghostNodes[nodeId] = ghost
                }
            } else if var ghost = ghostNodes[nodeId] {
                ghost.recovering = true
                ghost.driftProgress = max(0, ghost.driftProgress - deltaTime * 2.0)
                ghost.opacity = min(1.0, ghost.opacity + deltaTime * 2.0)
                if ghost.driftProgress <= 0 {
                    ghostNodes.removeValue(forKey: nodeId)
                } else {
                    ghostNodes[nodeId] = ghost
                }
            }
        }

        // Ripple detection — spawn when traffic increases
        if let tf = trafficFlow {
            let messagingNodes = ["slack", "discord", "signal", "imessage", "email"]
            for nodeId in messagingNodes {
                let current = tf[nodeId] ?? 0
                let previous = previousTrafficFlow[nodeId] ?? 0
                if current > previous + 0.2 {
                    activeRipples.append(Ripple(sourceNodeId: nodeId, startTime: heartbeatPhase))
                }
            }
            previousTrafficFlow = tf
        }

        // Advance and cull ripples
        activeRipples = activeRipples.compactMap { ripple in
            var r = ripple
            r.progress += deltaTime / 2.0
            return r.progress < 1.0 ? r : nil
        }
    }

    // MARK: - Node Position Computation

    func nodePosition(index: Int, baseX: Double, baseY: Double, cx: Double, cy: Double, screenWidth: Double, screenHeight: Double) -> (x: Double, y: Double, opacity: Double) {
        var x = baseX
        var y = baseY
        var opacity = 1.0

        // Boot: fly in from off-screen
        if mode == .booting {
            let order = nodeBootOrder.firstIndex(of: index) ?? index
            let threshold = Double(order) / 13.0
            let localProgress = min(1.0, max(0, (bootProgress - threshold) / 0.2))
            if localProgress < 1.0 {
                let angle = Double(index) * 27.7 * .pi / 180
                let startX = cx + cos(angle) * screenWidth * 1.5
                let startY = cy + sin(angle) * screenHeight * 1.5
                let eased = easeOutCubic(localProgress)
                x = startX + (baseX - startX) * eased
                y = startY + (baseY - startY) * eased
                opacity = localProgress
            }
            return (x, y, opacity)
        }

        // Constellation: lerp toward constellation positions
        if constellationProgress > 0 {
            let pattern = ConstellationPatterns.patterns[currentConstellation % ConstellationPatterns.count]
            if index < pattern.count {
                let target = pattern[index]
                let targetX = cx + target.x * screenWidth * 0.4
                let targetY = cy + target.y * screenHeight * 0.4
                let eased = easeInOutCubic(constellationProgress)
                x = x + (targetX - x) * eased
                y = y + (targetY - y) * eased
            }
        }

        return (x, y, opacity)
    }

    func ghostOffset(for nodeId: String, nx: Double, ny: Double, cx: Double, cy: Double) -> (x: Double, y: Double, opacity: Double) {
        guard let ghost = ghostNodes[nodeId] else { return (nx, ny, 1.0) }
        let dx = nx - cx
        let dy = ny - cy
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0 else { return (nx, ny, ghost.opacity) }
        let driftDist = ghost.driftProgress * dist * 0.3
        let offsetX = nx + (dx / dist) * driftDist
        let offsetY = ny + (dy / dist) * driftDist
        return (offsetX, offsetY, ghost.opacity)
    }

    // MARK: - Heartbeat Waveform

    func heartbeatAmplitude() -> Double {
        let t = heartbeatPhase.truncatingRemainder(dividingBy: 1.0)
        // Lub-dub: two peaks at t=0.1 and t=0.25
        let lub = exp(-pow((t - 0.1) * 15, 2))
        let dub = exp(-pow((t - 0.25) * 20, 2)) * 0.6
        return lub + dub
    }

    // MARK: - Easing

    private func easeOutCubic(_ t: Double) -> Double {
        let t1 = t - 1
        return t1 * t1 * t1 + 1
    }

    private func easeInOutCubic(_ t: Double) -> Double {
        return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }
}
