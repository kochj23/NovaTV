// ServiceActionSheet.swift
// NovaTV — Enterprise Feature #4: Service Action Controls
//
// Long-press context menu on status cards provides restart, silence, trigger
// actions. Posts to nova-control-web action endpoints with confirmation dialogs.
//
// Written by Jordan Koch.

import SwiftUI

// MARK: - Action Types

enum ServiceAction: String, CaseIterable, Identifiable {
    case restart = "restart"
    case silence = "silence"
    case trigger = "trigger"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .restart: return "Restart Service"
        case .silence: return "Silence Alerts"
        case .trigger: return "Trigger Now"
        }
    }

    var icon: String {
        switch self {
        case .restart: return "arrow.clockwise.circle.fill"
        case .silence: return "bell.slash.fill"
        case .trigger: return "play.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .restart: return .orange
        case .silence: return .yellow
        case .trigger: return .green
        }
    }

    var confirmationMessage: String {
        switch self {
        case .restart: return "This will restart the service. Active connections may be interrupted."
        case .silence: return "This will suppress alerts for this service for 30 minutes."
        case .trigger: return "This will immediately trigger the service/task."
        }
    }
}

// MARK: - Service Action View Modifier

struct ServiceActionModifier: ViewModifier {
    let serviceName: String
    @EnvironmentObject var dashboard: DashboardService
    @State private var showConfirmation = false
    @State private var pendingAction: ServiceAction?
    @State private var actionResult: ActionResult?

    func body(content: Content) -> some View {
        content
            .contextMenu {
                ForEach(ServiceAction.allCases) { action in
                    Button {
                        pendingAction = action
                        showConfirmation = true
                    } label: {
                        Label(action.label, systemImage: action.icon)
                    }
                }
            }
            .alert("Confirm Action", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) {
                    pendingAction = nil
                }
                Button(pendingAction?.label ?? "Confirm", role: pendingAction == .restart ? .destructive : nil) {
                    if let action = pendingAction {
                        executeAction(action)
                    }
                }
            } message: {
                Text(pendingAction?.confirmationMessage ?? "")
            }
            .overlay(alignment: .topTrailing) {
                if let result = actionResult {
                    ActionResultBadge(result: result)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(3))
                                withAnimation { actionResult = nil }
                            }
                        }
                }
            }
    }

    private func executeAction(_ action: ServiceAction) {
        Task {
            let success = await dashboard.postAction(service: serviceName, action: action.rawValue)
            withAnimation {
                actionResult = ActionResult(
                    success: success,
                    action: action,
                    service: serviceName
                )
            }
        }
    }
}

// MARK: - Action Result

struct ActionResult: Identifiable {
    let id = UUID()
    let success: Bool
    let action: ServiceAction
    let service: String
}

struct ActionResultBadge: View {
    let result: ActionResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.success ? .green : .red)
            Text(result.success ? "\(result.action.label) sent" : "Action failed")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(white: 0.12))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(
            (result.success ? Color.green : Color.red).opacity(0.4), lineWidth: 1
        ))
    }
}

// MARK: - View Extension

extension View {
    /// Adds long-press context menu with service actions (restart, silence, trigger)
    func serviceActions(for serviceName: String) -> some View {
        modifier(ServiceActionModifier(serviceName: serviceName))
    }
}
