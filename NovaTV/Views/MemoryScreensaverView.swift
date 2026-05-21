import SwiftUI

struct FloatingWord: Identifiable {
    let id = UUID()
    let text: String
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var fontSize: Double
    var opacity: Double
    var age: Double = 0
    let lifetime: Double
    var phase: FloatingPhase = .fadingIn

    enum FloatingPhase { case fadingIn, holding, fadingOut }
}

struct MemoryScreensaverView: View {
    @Environment(MemoryScreensaverService.self) var service
    @State private var floatingWords: [FloatingWord] = []
    @State private var phase: Double = 0
    @State private var scanlineOffset: Double = 0
    @State private var currentSource: String = ""
    @State private var currentCategory: String = ""
    @State private var currentYear: Int = 0
    @State private var lastMemoryId: UUID?

    private let timer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()
    private let cyanColor = Color(red: 0, green: 1, blue: 0.78)
    private let bgColor = Color(red: 0.02, green: 0.04, blue: 0.12)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            Canvas { context, size in
                // Scan lines
                drawScanLines(context: &context, size: size)

                // Floating words
                for word in floatingWords {
                    let font = Font.system(size: word.fontSize, weight: .medium, design: .monospaced)
                    context.draw(
                        Text(word.text).font(font).foregroundColor(cyanColor.opacity(word.opacity)),
                        at: CGPoint(x: word.x, y: word.y)
                    )
                }

                // Memory source metadata at bottom
                if !currentSource.isEmpty {
                    let metaFont = Font.system(size: 16, weight: .regular, design: .monospaced)
                    let metaText = "\(currentSource.uppercased()) · \(currentCategory) · \(currentYear > 0 ? String(currentYear) : "")"
                    context.draw(
                        Text(metaText).font(metaFont).foregroundColor(cyanColor.opacity(0.3)),
                        at: CGPoint(x: size.width / 2, y: size.height - 60)
                    )
                }

                // Title
                let titleFont = Font.system(size: 14, weight: .bold, design: .monospaced)
                context.draw(
                    Text("NOVA · MEMORY RECALL").font(titleFont).foregroundColor(cyanColor.opacity(0.2)),
                    at: CGPoint(x: size.width / 2, y: 40)
                )

                // Memory count
                let countFont = Font.system(size: 12, design: .monospaced)
                context.draw(
                    Text("1,482,791 VECTORS").font(countFont).foregroundColor(cyanColor.opacity(0.15)),
                    at: CGPoint(x: size.width / 2, y: size.height - 30)
                )
            }
            .onReceive(timer) { _ in
                tick()
            }
        }
        .onAppear {
            service.start()
        }
        .onDisappear {
            service.stop()
        }
    }

    private func tick() {
        phase += 1.0 / 30.0
        scanlineOffset += 0.5

        // Check for new memory
        if let mem = service.currentMemory, mem.id != lastMemoryId {
            lastMemoryId = mem.id
            spawnWords(from: mem)
            currentSource = mem.source
            currentCategory = mem.category
            currentYear = mem.year
        }

        // Update floating words
        floatingWords = floatingWords.compactMap { word in
            var w = word
            w.age += 1.0 / 30.0
            w.x += w.vx
            w.y += w.vy

            switch w.phase {
            case .fadingIn:
                w.opacity = min(1.0, w.age * 1.0)
                if w.age > 1.0 { w.phase = .holding }
            case .holding:
                w.opacity = 1.0
                if w.age > w.lifetime - 2.0 { w.phase = .fadingOut }
            case .fadingOut:
                let fadeProgress = (w.age - (w.lifetime - 2.0)) / 2.0
                w.opacity = max(0, 1.0 - fadeProgress)
            }

            return w.age < w.lifetime ? w : nil
        }
    }

    private func spawnWords(from memory: MemoryItem) {
        let words = memory.text.split(separator: " ").map(String.init)
        let screenWidth = 1920.0
        let screenHeight = 1080.0
        let baseX = Double.random(in: screenWidth * 0.15...screenWidth * 0.85)
        let baseY = Double.random(in: screenHeight * 0.2...screenHeight * 0.7)

        for (i, word) in words.enumerated() {
            let delay = Double(i) * 0.08
            let angle = Double.random(in: -0.3...0.3)
            let speed = Double.random(in: 0.1...0.4)

            let fw = FloatingWord(
                text: word,
                x: baseX + Double(i % 8) * 30 - 120 + Double.random(in: -20...20),
                y: baseY + Double(i / 8) * 40 + Double.random(in: -10...10),
                vx: cos(angle) * speed * (Bool.random() ? 1 : -1),
                vy: sin(angle) * speed * 0.3 - 0.1,
                fontSize: Double.random(in: 22...38),
                opacity: 0,
                lifetime: 7.0 + delay
            )
            floatingWords.append(fw)
        }
    }

    private func drawScanLines(context: inout GraphicsContext, size: CGSize) {
        let spacing = 4.0
        var y = scanlineOffset.truncatingRemainder(dividingBy: spacing)
        while y < size.height {
            context.fill(
                Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                with: .color(Color.white.opacity(0.008))
            )
            y += spacing
        }
    }
}
