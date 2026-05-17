// BurnInProtection.swift
// NovaTV — Enterprise Feature #5: Multi-Layout + Burn-In Protection
//
// Per-device layout profiles stored in UserDefaults (keyed by device UUID).
// Pixel-shift every 60s (2-4px random offset) to prevent OLED burn-in.
// Dim screen after 10 min idle (reduced opacity overlay).
//
// Written by Jordan Koch.

import SwiftUI
import Combine

// MARK: - Burn-In Protection Manager

@MainActor
final class BurnInProtectionManager: ObservableObject {
    /// Current pixel offset for burn-in prevention
    @Published var pixelOffset: CGSize = .zero

    /// Whether the display is in dimmed (idle) state
    @Published var isDimmed: Bool = false

    /// Opacity for the dim overlay (0 = fully visible, 0.7 = very dim)
    @Published var dimOpacity: Double = 0

    private var pixelShiftTimer: Timer?
    private var idleTimer: Timer?
    private var lastInteraction: Date = Date()

    /// Idle timeout before dimming (10 minutes)
    private let idleTimeout: TimeInterval = 600

    /// Pixel shift interval (60 seconds)
    private let shiftInterval: TimeInterval = 60

    /// Max pixel shift range
    private let maxShift: CGFloat = 4

    init() {
        startPixelShiftTimer()
        startIdleMonitor()
    }

    deinit {
        pixelShiftTimer?.invalidate()
        idleTimer?.invalidate()
    }

    // MARK: - Pixel Shift

    private func startPixelShiftTimer() {
        pixelShiftTimer = Timer.scheduledTimer(withTimeInterval: shiftInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyPixelShift()
            }
        }
    }

    private func applyPixelShift() {
        let dx = CGFloat.random(in: -maxShift...maxShift)
        let dy = CGFloat.random(in: -maxShift...maxShift)
        withAnimation(.easeInOut(duration: 2.0)) {
            pixelOffset = CGSize(width: dx, height: dy)
        }
    }

    // MARK: - Idle Detection

    private func startIdleMonitor() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkIdle()
            }
        }
    }

    private func checkIdle() {
        let elapsed = Date().timeIntervalSince(lastInteraction)
        if elapsed >= idleTimeout && !isDimmed {
            withAnimation(.easeIn(duration: 3.0)) {
                isDimmed = true
                dimOpacity = 0.6
            }
        }
    }

    /// Call this on any user interaction to reset idle timer
    func recordInteraction() {
        lastInteraction = Date()
        if isDimmed {
            withAnimation(.easeOut(duration: 0.5)) {
                isDimmed = false
                dimOpacity = 0
            }
        }
    }
}

// MARK: - Layout Profile

struct LayoutProfile: Codable, Identifiable {
    var id: String { deviceUUID }
    let deviceUUID: String
    var preferredStartPage: Int
    var showSidebar: Bool
    var compactMode: Bool
    var hudScale: Double
    var autoRotatePages: Bool
    var autoRotateInterval: TimeInterval

    static func defaultProfile(for uuid: String) -> LayoutProfile {
        LayoutProfile(
            deviceUUID: uuid,
            preferredStartPage: 0,
            showSidebar: true,
            compactMode: false,
            hudScale: 1.0,
            autoRotatePages: false,
            autoRotateInterval: 30
        )
    }
}

@MainActor
final class LayoutProfileManager: ObservableObject {
    @Published var currentProfile: LayoutProfile

    private let storageKey: String
    private let deviceUUID: String

    init() {
        // Use a stable device identifier
        let uuid = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
        self.deviceUUID = uuid
        self.storageKey = "layout_profile_\(uuid)"

        if let data = UserDefaults.standard.data(forKey: storageKey),
           let profile = try? JSONDecoder().decode(LayoutProfile.self, from: data) {
            self.currentProfile = profile
        } else {
            self.currentProfile = LayoutProfile.defaultProfile(for: uuid)
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(currentProfile) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func updateStartPage(_ page: Int) {
        currentProfile.preferredStartPage = page
        save()
    }

    func toggleSidebar() {
        currentProfile.showSidebar.toggle()
        save()
    }

    func toggleCompactMode() {
        currentProfile.compactMode.toggle()
        save()
    }

    func setHUDScale(_ scale: Double) {
        currentProfile.hudScale = max(0.5, min(1.5, scale))
        save()
    }

    func toggleAutoRotate() {
        currentProfile.autoRotatePages.toggle()
        save()
    }

    func setAutoRotateInterval(_ interval: TimeInterval) {
        currentProfile.autoRotateInterval = max(10, min(300, interval))
        save()
    }
}

// MARK: - Burn-In Protection View Modifier

struct BurnInProtectionModifier: ViewModifier {
    @EnvironmentObject var burnIn: BurnInProtectionManager

    func body(content: Content) -> some View {
        content
            .offset(burnIn.pixelOffset)
            .overlay {
                if burnIn.isDimmed {
                    Color.black
                        .opacity(burnIn.dimOpacity)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            .onMoveCommand { _ in
                burnIn.recordInteraction()
            }
    }
}

extension View {
    /// Applies burn-in protection: pixel shift + idle dimming
    func burnInProtection() -> some View {
        modifier(BurnInProtectionModifier())
    }
}
