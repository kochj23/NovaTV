import SwiftUI

struct PageMenuItem: Identifiable {
    let id: Int
    let name: String
    let icon: String
    let description: String
}

struct PageMenuOverlay: View {
    @Binding var isPresented: Bool
    @Binding var currentPage: Int
    @FocusState private var focusedItem: Int?

    private let cyanColor = Color(red: 0, green: 1, blue: 0.78)

    private let menuItems: [PageMenuItem] = [
        PageMenuItem(id: 0, name: "HUD", icon: "circle.hexagongrid.fill", description: "Radial orbital graph"),
        PageMenuItem(id: 1, name: "DASHBOARD", icon: "square.grid.2x2.fill", description: "System card grid"),
        PageMenuItem(id: 2, name: "JOURNAL", icon: "book.fill", description: "Publishing pipeline"),
        PageMenuItem(id: 3, name: "BIG BROTHER", icon: "eye.fill", description: "Self-healing oversight"),
        PageMenuItem(id: 4, name: "TRENDS", icon: "chart.xyaxis.line", description: "Sparkline metrics"),
        PageMenuItem(id: 5, name: "MEMORIES", icon: "text.book.closed.fill", description: "Dictionary screensaver"),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: 0) {
                Text("NOVA CONTROL")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(cyanColor.opacity(0.6))
                    .padding(.bottom, 8)

                Text("SELECT PAGE")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(cyanColor)
                    .padding(.bottom, 40)

                HStack(spacing: 30) {
                    ForEach(menuItems) { item in
                        menuCard(item: item)
                    }
                }
            }
        }
        .transition(.opacity)
        .onAppear {
            focusedItem = currentPage
        }
        .onExitCommand {
            dismiss()
        }
    }

    private func menuCard(item: PageMenuItem) -> some View {
        let isActive = item.id == currentPage
        let isFocused = focusedItem == item.id

        return Button {
            currentPage = item.id
            dismiss()
        } label: {
            VStack(spacing: 16) {
                Image(systemName: item.icon)
                    .font(.system(size: 44))
                    .foregroundColor(isActive ? cyanColor : cyanColor.opacity(0.5))

                Text(item.name)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(isActive ? cyanColor : cyanColor.opacity(0.7))

                Text(item.description)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(cyanColor.opacity(0.35))
                    .lineLimit(1)
            }
            .frame(width: 180, height: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isFocused ? 0.08 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isActive ? cyanColor.opacity(0.6) : cyanColor.opacity(isFocused ? 0.3 : 0.1), lineWidth: isActive ? 2 : 1)
            )
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
        .focused($focusedItem, equals: item.id)
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }
}
