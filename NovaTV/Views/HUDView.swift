import SwiftUI

/// Native tvOS HUD — radial sci-fi visualization rendered in SwiftUI Canvas.
/// Connects to the same WebSocket as the web dashboard and renders
/// the orbital node graph natively without WebKit.

struct HUDView: View {
    @EnvironmentObject var dashboard: DashboardService
    @State private var animationPhase: Double = 0
    
    private let timer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()
    
    // Colors
    private let cyanColor = Color(red: 0, green: 1, blue: 0.78)
    private let greenColor = Color(red: 0, green: 1, blue: 0.4)
    private let amberColor = Color(red: 1, green: 0.8, blue: 0)
    private let redColor = Color(red: 1, green: 0.2, blue: 0.27)
    private let dimColor = Color(red: 0.16, green: 0.22, blue: 0.31)
    private let bgColor = Color(red: 0.02, green: 0.04, blue: 0.12)
    
    // Node definitions — equally spaced around the gateway (360/13 ≈ 27.7° apart)
    // icon is an SF Symbol name
    private let nodeDefs: [(id: String, label: String, angle: Double, orbit: Orbit, intents: String, icon: String)] = [
        ("ollama", "OLLAMA", 0, .outer, "coder · vision · dreams", "hare.fill"),
        ("openrouter", "OPENROUTER", 28, .outer, "conversation · chat", "arrow.triangle.branch"),
        ("mlx", "MLX", 56, .outer, "memory · health · rag", "cpu"),
        ("redis", "REDIS", 84, .inner, "cache", "diamond.fill"),
        ("postgres", "POSTGRES", 112, .inner, "vectors", "cylinder.fill"),
        ("memory", "MEMORY", 140, .inner, "recall", "brain"),
        ("scheduler", "SCHEDULER", 168, .inner, "cron", "clock.fill"),
        ("searxng", "SEARXNG", 196, .inner, "search", "magnifyingglass"),
        ("slack", "SLACK", 224, .outer, "chat", "number"),
        ("discord", "DISCORD", 252, .outer, "notify", "gamecontroller.fill"),
        ("signal", "SIGNAL", 280, .outer, "private", "lock.shield.fill"),
        ("imessage", "iMESSAGE", 308, .outer, "relay", "message.fill"),
        ("email", "EMAIL", 336, .outer, "herd", "envelope.fill"),
    ]
    
    enum Orbit { case inner, outer }
    
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            
            Canvas { context, size in
                let cx = size.width * 0.55  // offset right to make room for left sidebar
                let cy = size.height * 0.47
                let unit = min(size.width, size.height) * 0.85  // slightly smaller to fit with sidebar
                let gatewayR = unit * 0.28
                let innerR = unit * 0.40
                let outerR = unit * 0.40  // Same distance — all nodes equidistant from gateway
                let nodeR = unit * 0.04
                
                // Background radial grid
                drawRadialGrid(context: &context, cx: cx, cy: cy, unit: unit, gatewayR: gatewayR)
                
                // Concentric gateway rings
                drawGatewayRings(context: &context, cx: cx, cy: cy, gatewayR: gatewayR)
                
                // Radar sweep
                drawRadarSweep(context: &context, cx: cx, cy: cy, gatewayR: gatewayR)
                
                // Orbit paths (dashed)
                drawOrbitPaths(context: &context, cx: cx, cy: cy, innerR: innerR, outerR: outerR)
                
                // Connection lines and nodes
                for def in nodeDefs {
                    let orbitR = def.orbit == .inner ? innerR : outerR
                    let rad = def.angle * .pi / 180
                    let nx = cx + cos(rad) * orbitR
                    let ny = cy + sin(rad) * orbitR
                    
                    // Connection line
                    drawConnectionLine(context: &context, cx: cx, cy: cy, nx: nx, ny: ny)

                    // Animated particles — count proportional to traffic
                    let nodeActivity = getActivity(def.id)
                    drawParticle(context: &context, cx: cx, cy: cy, nx: nx, ny: ny, phase: animationPhase, index: Double(nodeDefs.firstIndex(where: { $0.id == def.id }) ?? 0), activity: nodeActivity)

                    // Node circle
                    let activity = getActivity(def.id)
                    drawNode(context: &context, x: nx, y: ny, radius: nodeR, label: def.label, intents: def.intents, isHealthy: isServiceUp(def.id), activity: activity, icon: def.icon)
                }
                
                // Gateway center label
                let gatewayFont = Font.system(size: unit * 0.026, weight: .bold, design: .monospaced)
                context.draw(
                    Text("GATEWAY").font(gatewayFont).foregroundColor(cyanColor),
                    at: CGPoint(x: cx, y: cy)
                )
                
                // Req/s below gateway
                let gwIsUp = (dashboard.state?.gateway?.ok ?? false) || dashboard.state?.gateway?.status == "ok" || dashboard.state?.gateway?.status == "up" || dashboard.state?.gateway?.gatewayStatus == "live"
                let reqSec = gwIsUp ? "ONLINE" : "OFFLINE"
                let subFont = Font.system(size: unit * 0.014, design: .monospaced)
                context.draw(
                    Text(reqSec).font(subFont).foregroundColor(cyanColor.opacity(0.6)),
                    at: CGPoint(x: cx, y: cy + unit * 0.04)
                )
            }
            .onReceive(timer) { _ in
                animationPhase += 1.0 / 30.0
            }
            
            // Left sidebar - vital stats
            HStack {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text("NOVA CONTROL")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(cyanColor.opacity(0.9))

                    Text(timeString)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(cyanColor)

                    Divider().background(cyanColor.opacity(0.2))

                    sideStatRow("MEMORIES", memoryCountText)
                    sideStatRow("SCHEDULER", schedulerText)
                    sideStatRow("CPU", cpuText)
                    sideStatRow("RAM", ramText)
                    sideStatRow("MODELS", modelsText)
                    sideStatRow("UPTIME", uptimeText)

                    Divider().background(cyanColor.opacity(0.2))

                    // Status LEDs
                    VStack(alignment: .leading, spacing: 8) {
                        ledRow("GATEWAY", isServiceUp("gateway"))
                        ledRow("OLLAMA", isServiceUp("ollama"))
                        ledRow("MEMORY", isServiceUp("memory"))
                        ledRow("REDIS", isServiceUp("redis"))
                        ledRow("POSTGRES", isServiceUp("postgres"))
                        ledRow("SCHEDULER", isServiceUp("scheduler"))
                        ledRow("SEARXNG", isServiceUp("searxng"))
                    }

                    // Agent status
                    if let agents = dashboard.state?.agents, !agents.isEmpty {
                        Divider().background(cyanColor.opacity(0.2))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("AGENTS")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(cyanColor.opacity(0.5))
                            ForEach(Array(agents.sorted(by: { $0.key < $1.key })), id: \.key) { name, agent in
                                agentLedRow(name.uppercased(), agent)
                            }
                        }
                    }

                    Spacer()
                }
                .frame(width: 220)
                .padding(.leading, 40)
                .padding(.top, 50)

                Spacer()
            }
        }
    }
    
    // MARK: - Drawing helpers
    
    private func drawRadialGrid(context: inout GraphicsContext, cx: Double, cy: Double, unit: Double, gatewayR: Double) {
        let maxR = max(cx, cy) * 1.2
        let spacing = unit * 0.04
        var r = spacing
        while r < maxR {
            let opacity = 0.02 - (r / maxR) * 0.015
            if opacity > 0 {
                context.stroke(
                    Path { p in p.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: .zero, endAngle: .degrees(360), clockwise: false) },
                    with: .color(cyanColor.opacity(opacity)),
                    lineWidth: 0.5
                )
            }
            r += spacing
        }
        
        // Radial lines
        for i in 0..<72 {
            let angle = Double(i) * 5.0 * .pi / 180
            let isMajor = i % 6 == 0
            let opacity = isMajor ? 0.03 : 0.01
            context.stroke(
                Path { p in
                    p.move(to: CGPoint(x: cx + cos(angle) * gatewayR * 0.4, y: cy + sin(angle) * gatewayR * 0.4))
                    p.addLine(to: CGPoint(x: cx + cos(angle) * maxR, y: cy + sin(angle) * maxR))
                },
                with: .color(cyanColor.opacity(opacity)),
                lineWidth: isMajor ? 0.8 : 0.4
            )
        }
    }
    
    private func drawGatewayRings(context: inout GraphicsContext, cx: Double, cy: Double, gatewayR: Double) {
        for ring in 0..<6 {
            let ringR = gatewayR * (0.35 + Double(ring + 1) * 0.12)
            let opacity = 0.12 - Double(ring) * 0.015
            context.stroke(
                Path { p in p.addArc(center: CGPoint(x: cx, y: cy), radius: ringR, startAngle: .zero, endAngle: .degrees(360), clockwise: false) },
                with: .color(cyanColor.opacity(opacity)),
                lineWidth: ring == 0 ? 2.0 : 1.0
            )
            
            // Rotating arc segments on each ring
            let arcOffset = animationPhase * (0.3 + Double(ring) * 0.1) * (ring % 2 == 0 ? 1 : -1)
            for seg in 0..<4 {
                let start = Angle.degrees(Double(seg) * 90 + arcOffset * 57.3)
                let end = start + .degrees(30 + Double(ring) * 5)
                context.stroke(
                    Path { p in p.addArc(center: CGPoint(x: cx, y: cy), radius: ringR, startAngle: start, endAngle: end, clockwise: false) },
                    with: .color(cyanColor.opacity(0.25)),
                    lineWidth: 2.5
                )
            }
        }
        
        // Tick marks
        for i in 0..<120 {
            let angle = Double(i) * 3.0 * .pi / 180
            let isMajor = i % 10 == 0
            let innerTick = gatewayR * (isMajor ? 0.92 : 0.95)
            let outerTick = gatewayR * 1.0
            context.stroke(
                Path { p in
                    p.move(to: CGPoint(x: cx + cos(angle) * innerTick, y: cy + sin(angle) * innerTick))
                    p.addLine(to: CGPoint(x: cx + cos(angle) * outerTick, y: cy + sin(angle) * outerTick))
                },
                with: .color(cyanColor.opacity(isMajor ? 0.4 : 0.15)),
                lineWidth: isMajor ? 1.5 : 0.8
            )
        }
    }
    
    private func drawRadarSweep(context: inout GraphicsContext, cx: Double, cy: Double, gatewayR: Double) {
        // Radar sweep disabled per user request
    }
    
    private func drawOrbitPaths(context: inout GraphicsContext, cx: Double, cy: Double, innerR: Double, outerR: Double) {
        context.stroke(
            Path { p in p.addArc(center: CGPoint(x: cx, y: cy), radius: innerR, startAngle: .zero, endAngle: .degrees(360), clockwise: false) },
            with: .color(cyanColor.opacity(0.06)),
            style: StrokeStyle(lineWidth: 1, dash: [4, 8])
        )
        context.stroke(
            Path { p in p.addArc(center: CGPoint(x: cx, y: cy), radius: outerR, startAngle: .zero, endAngle: .degrees(360), clockwise: false) },
            with: .color(cyanColor.opacity(0.04)),
            style: StrokeStyle(lineWidth: 1, dash: [4, 8])
        )
    }
    
    private func drawConnectionLine(context: inout GraphicsContext, cx: Double, cy: Double, nx: Double, ny: Double) {
        context.stroke(
            Path { p in
                p.move(to: CGPoint(x: cx, y: cy))
                p.addLine(to: CGPoint(x: nx, y: ny))
            },
            with: .color(cyanColor.opacity(0.12)),
            lineWidth: 1
        )
    }

    private func drawParticle(context: inout GraphicsContext, cx: Double, cy: Double, nx: Double, ny: Double, phase: Double, index: Double, activity: Double) {
        // Number of particles proportional to activity (min 1, max 8)
        let particleCount = max(1, Int(1 + activity * 7))
        let speed = 0.3 + activity * 0.5  // faster when busier

        for i in 0..<particleCount {
            let offset = Double(i) / Double(particleCount)
            let t = (phase * speed + index * 0.12 + offset).truncatingRemainder(dividingBy: 1.0)

            let px = cx + (nx - cx) * t
            let py = cy + (ny - cy) * t
            let size = 2.5 + sin(t * .pi) * 2.0 + activity * 2.0  // bigger when busier
            let alpha = sin(t * .pi) * (0.5 + activity * 0.4)

            context.fill(
                Path { p in p.addArc(center: CGPoint(x: px, y: py), radius: size, startAngle: .zero, endAngle: .degrees(360), clockwise: false) },
                with: .color(cyanColor.opacity(alpha))
            )
        }
    }
    
    private func drawNode(context: inout GraphicsContext, x: Double, y: Double, radius: Double, label: String, intents: String, isHealthy: Bool, activity: Double, icon: String) {
        let borderCol = isHealthy ? cyanColor : redColor

        // Interior fill color based on state:
        // Down = red, idle (0) = green, busy (0.5) = yellow, very busy (1.0) = orange
        let fillCol: Color
        let fillOpacity: Double
        if !isHealthy {
            fillCol = redColor
            fillOpacity = 0.35
        } else if activity < 0.01 {
            fillCol = greenColor
            fillOpacity = 0.08
        } else if activity < 0.3 {
            // Green to yellow
            fillCol = Color(red: activity / 0.3, green: 1.0, blue: 0)
            fillOpacity = 0.15 + activity * 0.3
        } else if activity < 0.7 {
            // Yellow to orange
            let t = (activity - 0.3) / 0.4
            fillCol = Color(red: 1.0, green: 1.0 - t * 0.4, blue: 0)
            fillOpacity = 0.25 + t * 0.2
        } else {
            // Orange to red-orange (very busy)
            let t = (activity - 0.7) / 0.3
            fillCol = Color(red: 1.0, green: 0.6 - t * 0.3, blue: 0)
            fillOpacity = 0.4 + t * 0.15
        }

        // Glow halo
        context.fill(
            Path { p in p.addArc(center: CGPoint(x: x, y: y), radius: radius * 2.0, startAngle: .zero, endAngle: .degrees(360), clockwise: false) },
            with: .color(borderCol.opacity(0.06))
        )

        // Filled interior (activity-colored)
        context.fill(
            Path { p in p.addArc(center: CGPoint(x: x, y: y), radius: radius, startAngle: .zero, endAngle: .degrees(360), clockwise: false) },
            with: .color(fillCol.opacity(fillOpacity))
        )

        // Border ring
        context.stroke(
            Path { p in p.addArc(center: CGPoint(x: x, y: y), radius: radius, startAngle: .zero, endAngle: .degrees(360), clockwise: false) },
            with: .color(borderCol.opacity(0.6)),
            lineWidth: 2
        )

        // Inner ring
        context.stroke(
            Path { p in p.addArc(center: CGPoint(x: x, y: y), radius: radius * 0.6, startAngle: .zero, endAngle: .degrees(360), clockwise: false) },
            with: .color(borderCol.opacity(0.2)),
            lineWidth: 0.8
        )

        // Center icon (SF Symbol)
        let iconSize = max(14, radius * 0.55)
        let iconColor = isHealthy ? cyanColor.opacity(0.85) : redColor.opacity(0.85)
        context.draw(
            Text(Image(systemName: icon)).font(.system(size: iconSize)).foregroundColor(iconColor),
            at: CGPoint(x: x, y: y)
        )

        // Label
        let font = Font.system(size: max(10, radius * 0.45), weight: .medium, design: .monospaced)
        context.draw(
            Text(label).font(font).foregroundColor(borderCol.opacity(0.8)),
            at: CGPoint(x: x, y: y + radius + 14)
        )

        // Intent sublabel
        let subFont = Font.system(size: max(8, radius * 0.3), design: .monospaced)
        context.draw(
            Text(intents).font(subFont).foregroundColor(borderCol.opacity(0.35)),
            at: CGPoint(x: x, y: y + radius + 28)
        )
    }
    
    // MARK: - State helpers
    
    private func isServiceUp(_ id: String) -> Bool {
        guard let state = dashboard.state else { return false }

        // Helper: check if a status string means "healthy"
        func isHealthy(_ s: String?) -> Bool {
            guard let s = s else { return false }
            return s == "up" || s == "ok" || s == "live" || s == "running" || s == "connected"
        }

        switch id {
        case "ollama", "mlx_chat", "memory_server", "tinychat", "comfyui", "openwebui", "swarmui", "searxng":
            return state.services?[id]?.status == "up"
        case "gateway":
            return (state.gateway?.ok ?? false) || isHealthy(state.gateway?.status) || isHealthy(state.gateway?.gatewayStatus)
        case "redis":
            return isHealthy(state.redis?.status)
        case "postgres", "postgresql":
            return isHealthy(state.postgresql?.status)
        case "scheduler":
            return isHealthy(state.scheduler?.status) || state.scheduler?.info != nil
        case "slack", "discord", "signal", "imessage", "email", "openrouter", "mlx":
            return (state.gateway?.ok ?? false) || isHealthy(state.gateway?.status)
        case "memory":
            return state.services?["memory_server"]?.status == "up"
        default:
            return state.services?[id]?.status == "up"
        }
    }
    
    private var memoryCountText: String { return "1.38M" }




    
    private var schedulerText: String {
        guard let s = dashboard.state?.scheduler else { return "—" }
        return "\(((s.info?.tasksTotal ?? 0) - (s.info?.totalFailures ?? 0)))/\((s.info?.tasksTotal ?? 0))"
    }
    
    private var cpuText: String {
        guard let sys = dashboard.state?.system else { return "—" }
        return "\(Int((sys.cpuPercent ?? 0)))%"
    }
    
    private var ramText: String {
        guard let sys = dashboard.state?.system else { return "—" }
        return "\(Int((sys.memory?.percent ?? 0)))%"
    }
    
    private var modelsText: String {
        guard let o = dashboard.state?.ollama else { return "—" }
        return "\(o.modelCount ?? 0)"
    }
    
    private var uptimeText: String {
        guard let s = dashboard.state?.scheduler else { return "—" }
        let hours = ((s.info?.uptimeS ?? 0)) / 3600
        return "\(hours)h"
    }
    
    private func getActivity(_ id: String) -> Double {
        // Get traffic flow values from the WebSocket state (0.0 - 1.0)
        guard let flows = dashboard.state?.trafficFlow else { return 0.0 }
        switch id {
        case "slack": return flows["slack"] ?? 0
        case "discord": return flows["discord"] ?? 0
        case "signal": return flows["signal"] ?? 0
        case "imessage": return flows["imessage"] ?? 0
        case "email": return flows["email"] ?? 0
        case "ollama": return flows["ollama"] ?? 0
        case "openrouter": return flows["openrouter"] ?? 0
        case "mlx": return flows["mlx_chat"] ?? 0
        case "redis": return flows["redis"] ?? 0
        case "postgres": return flows["postgresql"] ?? 0
        case "memory": return flows["memory_server"] ?? 0
        case "scheduler": return flows["scheduler"] ?? 0
        case "searxng": return flows["searxng"] ?? 0
        default: return 0
        }
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
    
    private func statLabel(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 18, design: .monospaced))
                .foregroundColor(cyanColor.opacity(0.5))
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(cyanColor)
        }
    }

    private func sideStatRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(cyanColor.opacity(0.5))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(cyanColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func ledRow(_ name: String, _ isUp: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isUp ? greenColor : redColor)
                .frame(width: 10, height: 10)
                .shadow(color: isUp ? greenColor : redColor, radius: 4)
            Text(name)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(cyanColor.opacity(0.6))
        }
    }

    private func agentLedRow(_ name: String, _ agent: AgentState) -> some View {
        let isUp = agent.status == "running"
        return HStack(spacing: 10) {
            Circle()
                .fill(isUp ? greenColor : (agent.status == "error" ? redColor : amberColor))
                .frame(width: 10, height: 10)
                .shadow(color: isUp ? greenColor : redColor, radius: 4)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(cyanColor.opacity(0.6))
                if let model = agent.model, model != "unknown" {
                    Text(model.count > 20 ? String(model.suffix(20)) : model)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(cyanColor.opacity(0.3))
                        .lineLimit(1)
                }
            }
        }
    }
}
