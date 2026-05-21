import Foundation

struct ConstellationPatterns {
    static let count = 4

    // Each pattern has 13 normalized (x, y) positions centered around (0, 0)
    // Range approximately -1...1 for both axes

    static let patterns: [[CGPoint]] = [
        // Orion — belt + shoulders + feet + sword
        orion,
        // Cassiopeia — W shape spread across 13 points
        cassiopeia,
        // Big Dipper + handle extended
        bigDipper,
        // Scorpius — curved tail with stinger
        scorpius,
    ]

    private static let orion: [CGPoint] = [
        CGPoint(x: -0.15, y: -0.05),  // Betelgeuse (left shoulder)
        CGPoint(x:  0.15, y: -0.05),  // Bellatrix (right shoulder)
        CGPoint(x: -0.05, y:  0.15),  // Belt left (Alnitak)
        CGPoint(x:  0.00, y:  0.15),  // Belt center (Alnilam)
        CGPoint(x:  0.05, y:  0.15),  // Belt right (Mintaka)
        CGPoint(x: -0.20, y:  0.45),  // Saiph (left foot)
        CGPoint(x:  0.20, y:  0.45),  // Rigel (right foot)
        CGPoint(x:  0.00, y:  0.25),  // Sword top
        CGPoint(x:  0.00, y:  0.30),  // Sword nebula
        CGPoint(x:  0.00, y:  0.35),  // Sword bottom
        CGPoint(x: -0.25, y: -0.20),  // Above Betelgeuse
        CGPoint(x:  0.25, y: -0.20),  // Above Bellatrix
        CGPoint(x:  0.00, y: -0.30),  // Head (Meissa)
    ]

    private static let cassiopeia: [CGPoint] = [
        CGPoint(x: -0.60, y:  0.00),  // Segin
        CGPoint(x: -0.40, y: -0.25),  // Ruchbah
        CGPoint(x: -0.15, y:  0.05),  // Gamma Cas (center peak)
        CGPoint(x:  0.10, y: -0.25),  // Schedar
        CGPoint(x:  0.35, y:  0.00),  // Caph
        // Extended stars filling the W arms
        CGPoint(x: -0.50, y: -0.12),
        CGPoint(x: -0.28, y: -0.10),
        CGPoint(x: -0.02, y: -0.10),
        CGPoint(x:  0.22, y: -0.12),
        // Faint surrounding stars
        CGPoint(x: -0.55, y:  0.15),
        CGPoint(x:  0.00, y:  0.20),
        CGPoint(x:  0.30, y:  0.15),
        CGPoint(x:  0.50, y: -0.10),
    ]

    private static let bigDipper: [CGPoint] = [
        // Bowl
        CGPoint(x: -0.10, y: -0.10),  // Dubhe
        CGPoint(x: -0.05, y:  0.10),  // Merak
        CGPoint(x:  0.15, y:  0.12),  // Phecda
        CGPoint(x:  0.20, y: -0.05),  // Megrez
        // Handle
        CGPoint(x:  0.35, y: -0.10),  // Alioth
        CGPoint(x:  0.50, y: -0.05),  // Mizar
        CGPoint(x:  0.65, y:  0.05),  // Alkaid
        // Extended stars (Polaris direction + filler)
        CGPoint(x: -0.30, y: -0.30),  // Toward Polaris
        CGPoint(x: -0.20, y: -0.45),  // Polaris
        CGPoint(x:  0.52, y: -0.02),  // Alcor (next to Mizar)
        CGPoint(x:  0.00, y:  0.25),
        CGPoint(x:  0.30, y:  0.20),
        CGPoint(x: -0.25, y:  0.15),
    ]

    private static let scorpius: [CGPoint] = [
        CGPoint(x: -0.30, y: -0.40),  // Dschubba (head)
        CGPoint(x: -0.20, y: -0.35),  // Head star 2
        CGPoint(x: -0.10, y: -0.25),  // Antares
        CGPoint(x: -0.05, y: -0.10),  // Body
        CGPoint(x:  0.00, y:  0.05),  // Body curve
        CGPoint(x:  0.10, y:  0.18),  // Tail curve
        CGPoint(x:  0.20, y:  0.28),  // Tail
        CGPoint(x:  0.30, y:  0.35),  // Tail end
        CGPoint(x:  0.38, y:  0.30),  // Stinger (Shaula)
        CGPoint(x:  0.35, y:  0.40),  // Stinger (Lesath)
        // Claws extending up-left
        CGPoint(x: -0.45, y: -0.50),
        CGPoint(x: -0.50, y: -0.35),
        CGPoint(x: -0.40, y: -0.45),
    ]
}
