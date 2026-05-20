import Foundation

protocol CounterRepository: Sendable {
    func current() async -> Int
    func increment() async -> Int
}

actor InMemoryCounterRepository: CounterRepository {
    private var value: Int = 0
    func current() async -> Int { value }
    func increment() async -> Int {
        value += 1
        return value
    }
}
