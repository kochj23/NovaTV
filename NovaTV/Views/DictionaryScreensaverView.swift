import SwiftUI

struct DictionaryEntry: Identifiable {
    let id = UUID()
    let word: String
    let definition: String
    let source: String
    let category: String
    let year: Int
    var yOffset: Double
    var opacity: Double = 1.0
}

struct DictionaryScreensaverView: View {
    @Environment(MemoryScreensaverService.self) var service
    @State private var entries: [DictionaryEntry] = []
    @State private var scrollOffset: Double = 0
    @State private var phase: Double = 0

    private let timer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()
    private let cyanColor = Color(red: 0, green: 1, blue: 0.78)
    private let bgColor = Color(red: 0.02, green: 0.04, blue: 0.12)

    private let scrollSpeed: Double = 0.6
    private let entrySpacing: Double = 220
    private let screenHeight: Double = 1080

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            Canvas { context, size in
                drawScanLines(context: &context, size: size)

                let visibleEntries = entries.filter { entry in
                    let y = entry.yOffset - scrollOffset
                    return y > -300 && y < size.height + 100
                }

                for entry in visibleEntries {
                    let y = entry.yOffset - scrollOffset
                    let centerDist = abs(y - size.height / 2) / (size.height / 2)
                    let fadeOpacity = max(0, 1.0 - pow(centerDist, 1.8))

                    drawEntry(context: &context, entry: entry, x: size.width * 0.12, y: y, maxWidth: size.width * 0.76, opacity: fadeOpacity)
                }

                let titleFont = Font.system(size: 14, weight: .bold, design: .monospaced)
                context.draw(
                    Text("NOVA · MEMORY DICTIONARY").font(titleFont).foregroundColor(cyanColor.opacity(0.15)),
                    at: CGPoint(x: size.width / 2, y: 30)
                )

                let countFont = Font.system(size: 12, design: .monospaced)
                context.draw(
                    Text("1,482,791 VECTORS · \(entries.count) ENTRIES LOADED").font(countFont).foregroundColor(cyanColor.opacity(0.12)),
                    at: CGPoint(x: size.width / 2, y: size.height - 25)
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
        scrollOffset += scrollSpeed

        if let mem = service.currentMemory {
            let alreadyHas = entries.contains { $0.word == extractHeadword(from: mem.text) }
            if !alreadyHas {
                let newY = (entries.last?.yOffset ?? scrollOffset) + entrySpacing
                let entry = DictionaryEntry(
                    word: extractHeadword(from: mem.text),
                    definition: mem.text,
                    source: mem.source,
                    category: mem.category,
                    year: mem.year,
                    yOffset: newY
                )
                entries.append(entry)
            }
        }

        // Request next memory when we're getting close to needing it
        let bottomVisible = scrollOffset + screenHeight
        if let last = entries.last, last.yOffset - bottomVisible < entrySpacing * 3 {
            service.advance()
        }

        // Cull entries that have scrolled far above viewport
        entries.removeAll { $0.yOffset < scrollOffset - 400 }
    }

    private func drawEntry(context: inout GraphicsContext, entry: DictionaryEntry, x: Double, y: Double, maxWidth: Double, opacity: Double) {
        guard opacity > 0.01 else { return }

        let headwordFont = Font.system(size: 42, weight: .bold, design: .serif)
        let defFont = Font.system(size: 20, weight: .regular, design: .serif)
        let metaFont = Font.system(size: 13, weight: .light, design: .monospaced)

        // Headword
        context.draw(
            Text(entry.word)
                .font(headwordFont)
                .foregroundColor(cyanColor.opacity(opacity * 0.95)),
            at: CGPoint(x: x + maxWidth / 2, y: y)
        )

        // Thin divider line
        let dividerY = y + 30
        context.stroke(
            Path { p in
                p.move(to: CGPoint(x: x + maxWidth * 0.2, y: dividerY))
                p.addLine(to: CGPoint(x: x + maxWidth * 0.8, y: dividerY))
            },
            with: .color(cyanColor.opacity(opacity * 0.12)),
            lineWidth: 0.5
        )

        // Definition text (truncated to fit)
        let defText = String(entry.definition.prefix(200))
        context.draw(
            Text(defText)
                .font(defFont)
                .foregroundColor(cyanColor.opacity(opacity * 0.6))
                .lineLimit(3),
            at: CGPoint(x: x + maxWidth / 2, y: y + 65)
        )

        // Source metadata
        let meta = "\(entry.source.uppercased()) · \(entry.category) · \(entry.year > 0 ? String(entry.year) : "")"
        context.draw(
            Text(meta)
                .font(metaFont)
                .foregroundColor(cyanColor.opacity(opacity * 0.25)),
            at: CGPoint(x: x + maxWidth / 2, y: y + 110)
        )
    }

    private func extractHeadword(from text: String) -> String {
        let words = text.split(separator: " ")
        if words.count >= 2 {
            // Use first 1-3 words as the "headword" depending on length
            let candidate = words.prefix(3).joined(separator: " ")
            if candidate.count <= 30 {
                return candidate.capitalized
            }
            return String(words.prefix(2).joined(separator: " ")).capitalized
        }
        return String(text.prefix(25)).capitalized
    }

    private func drawScanLines(context: inout GraphicsContext, size: CGSize) {
        let spacing = 3.0
        let scanPhase = phase * 0.3
        var y = (scanPhase * spacing).truncatingRemainder(dividingBy: spacing)
        while y < size.height {
            context.fill(
                Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)),
                with: .color(Color.white.opacity(0.006))
            )
            y += spacing
        }
    }
}
