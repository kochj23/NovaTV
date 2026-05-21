import SwiftUI

struct HUDEffects {
    static let cyanColor = Color(red: 0, green: 1, blue: 0.78)
    static let purpleColor = Color(red: 0.4, green: 0.1, blue: 0.8)
    static let pinkColor = Color(red: 0.9, green: 0.3, blue: 0.5)
    static let goldColor = Color(red: 1.0, green: 0.85, blue: 0.3)

    // MARK: - Aurora Background

    static func drawAurora(context: inout GraphicsContext, size: CGSize, phase: Double) {
        let hour = Calendar.current.component(.hour, from: Date())
        let palette = auroraPalette(hour: hour)

        for i in 0..<3 {
            let bandPhase = phase + Double(i) * 2.1
            let yBase = size.height * (0.3 + Double(i) * 0.2)
            let amplitude = size.height * 0.08

            var path = Path()
            path.move(to: CGPoint(x: 0, y: yBase + sin(bandPhase) * amplitude))
            for x in stride(from: 0, through: size.width, by: 8) {
                let t = x / size.width
                let y = yBase + sin(bandPhase + t * 4.0) * amplitude + cos(bandPhase * 0.7 + t * 2.5) * amplitude * 0.5
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: size.width, y: yBase + amplitude * 3))
            path.addLine(to: CGPoint(x: 0, y: yBase + amplitude * 3))
            path.closeSubpath()

            let color = palette[i % palette.count]
            context.fill(path, with: .color(color.opacity(0.04 + sin(bandPhase * 0.3) * 0.01)))
        }
    }

    private static func auroraPalette(hour: Int) -> [Color] {
        switch hour {
        case 22...23, 0..<5:
            return [purpleColor, Color(red: 0, green: 0.5, blue: 0.7), Color(red: 0.2, green: 0, blue: 0.5)]
        case 5..<10:
            return [pinkColor, goldColor, Color(red: 1.0, green: 0.6, blue: 0.3)]
        case 10..<17:
            return [cyanColor, Color.white, Color(red: 0.5, green: 0.9, blue: 1.0)]
        default:
            return [Color(red: 1, green: 0.5, blue: 0.1), Color(red: 0.1, green: 0.1, blue: 0.5), purpleColor]
        }
    }

    // MARK: - Heartbeat Pulse

    static func drawHeartbeatPulse(context: inout GraphicsContext, cx: Double, cy: Double, gatewayR: Double, amplitude: Double, phase: Double) {
        guard amplitude > 0.01 else { return }

        // Expanding pulse ring
        let ringProgress = phase.truncatingRemainder(dividingBy: 1.0)
        let ringR = gatewayR * (0.4 + ringProgress * 0.7)
        let ringOpacity = amplitude * 0.25 * (1.0 - ringProgress)

        if ringOpacity > 0.005 {
            context.stroke(
                Path { p in p.addArc(center: CGPoint(x: cx, y: cy), radius: ringR, startAngle: .zero, endAngle: .degrees(360), clockwise: false) },
                with: .color(cyanColor.opacity(ringOpacity)),
                lineWidth: 2.0 + amplitude * 2.0
            )
        }

        // Inner glow that pulses
        let glowR = gatewayR * 0.3 * (1.0 + amplitude * 0.08)
        context.fill(
            Path { p in p.addArc(center: CGPoint(x: cx, y: cy), radius: glowR, startAngle: .zero, endAngle: .degrees(360), clockwise: false) },
            with: .color(cyanColor.opacity(amplitude * 0.1))
        )
    }

    // MARK: - Ghost Trail Afterimages

    static func drawGhostTrail(context: inout GraphicsContext, nx: Double, ny: Double, cx: Double, cy: Double, ghost: GhostState, phase: Double) {
        let dx = nx - cx
        let dy = ny - cy
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0 else { return }
        let dirX = dx / dist
        let dirY = dy / dist

        // Draw 3 fading afterimages trailing behind the ghost
        for i in 1...3 {
            let trailDist = ghost.driftProgress * dist * 0.3 * (1.0 - Double(i) * 0.25)
            let tx = nx + dirX * trailDist
            let ty = ny + dirY * trailDist
            let trailOpacity = ghost.opacity * 0.3 / Double(i)
            // Subtle jitter for static effect
            let jitterX = sin(phase * 7.0 + Double(i) * 2.3) * 2.0
            let jitterY = cos(phase * 5.0 + Double(i) * 1.7) * 2.0

            context.fill(
                Path { p in p.addArc(center: CGPoint(x: tx + jitterX, y: ty + jitterY), radius: 6, startAngle: .zero, endAngle: .degrees(360), clockwise: false) },
                with: .color(Color.red.opacity(trailOpacity))
            )
        }
    }

    // MARK: - Message Ripples

    static func drawRipples(context: inout GraphicsContext, ripples: [Ripple], nodePositions: [String: CGPoint], cx: Double, cy: Double) {
        for ripple in ripples {
            guard let nodePos = nodePositions[ripple.sourceNodeId] else { continue }
            let progress = ripple.progress

            // 3 concentric arcs traveling from node toward center
            for ring in 0..<3 {
                let ringDelay = Double(ring) * 0.15
                let ringProgress = max(0, progress - ringDelay)
                guard ringProgress > 0 && ringProgress < 1.0 else { continue }

                let t = ringProgress
                let px = nodePos.x + (cx - nodePos.x) * t
                let py = nodePos.y + (cy - nodePos.y) * t
                let radius = 8 + t * 15
                let opacity = (1.0 - t) * 0.4

                context.stroke(
                    Path { p in p.addArc(center: CGPoint(x: px, y: py), radius: radius, startAngle: .zero, endAngle: .degrees(360), clockwise: false) },
                    with: .color(cyanColor.opacity(opacity)),
                    lineWidth: 1.5
                )
            }
        }
    }

    // MARK: - Constellation Twinkling

    static func constellationTwinkle(phase: Double, nodeIndex: Int) -> Double {
        return 0.5 + 0.5 * sin(phase * 2.0 + Double(nodeIndex) * 1.3)
    }
}
