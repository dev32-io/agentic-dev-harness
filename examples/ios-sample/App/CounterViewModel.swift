import Foundation
import Observation

@Observable
@MainActor
final class CounterViewModel {
    private(set) var count: Int = 0
    private(set) var toast: String?
    private let repository: CounterRepository

    init(repository: CounterRepository = InMemoryCounterRepository()) {
        self.repository = repository
        Task { await load() }
    }

    func load() async {
        count = await repository.current()
    }

    func increment() async {
        count = await repository.increment()
        toast = "Incremented"
    }

    func toastShown() {
        toast = nil
    }
}
