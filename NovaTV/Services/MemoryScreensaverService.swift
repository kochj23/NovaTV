import Foundation

struct MemoryItem: Identifiable {
    let id = UUID()
    let text: String
    let source: String
    let category: String
    let year: Int
}

@Observable
final class MemoryScreensaverService {
    var currentMemory: MemoryItem?
    var memoryQueue: [MemoryItem] = []
    private var fetchTask: Task<Void, Never>?
    private let baseURL = "http://192.168.1.6:37450"

    func start() {
        guard fetchTask == nil else { return }
        fetchTask = Task { [weak self] in
            await self?.prefillQueue()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                await self?.advance()
            }
        }
    }

    func stop() {
        fetchTask?.cancel()
        fetchTask = nil
    }

    private func prefillQueue() async {
        for _ in 0..<5 {
            if let item = await fetchOne() {
                await MainActor.run { memoryQueue.append(item) }
            }
        }
        await MainActor.run { advance() }
    }

    @MainActor
    func advance() {
        if !memoryQueue.isEmpty {
            currentMemory = memoryQueue.removeFirst()
        }
        Task {
            if let item = await fetchOne() {
                await MainActor.run { memoryQueue.append(item) }
            }
        }
    }

    private func fetchOne() async -> MemoryItem? {
        guard let url = URL(string: "\(baseURL)/api/random-memory") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String,
               text != "No memory available" {
                return MemoryItem(
                    text: text,
                    source: json["source"] as? String ?? "unknown",
                    category: json["category"] as? String ?? "",
                    year: json["year"] as? Int ?? 0
                )
            }
        } catch {}
        return nil
    }
}
