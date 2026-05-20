import Testing
@testable import App

@MainActor
struct CounterViewModelTests {

    @Test func starts_at_zero() async {
        let vm = CounterViewModel(repository: InMemoryCounterRepository())
        await vm.load()
        #expect(vm.count == 0)
    }

    @Test func increment_advances_count_and_sets_toast() async {
        let vm = CounterViewModel(repository: InMemoryCounterRepository())
        await vm.load()
        await vm.increment()
        #expect(vm.count == 1)
        #expect(vm.toast == "Incremented")
    }

    @Test func toast_shown_clears_toast() async {
        let vm = CounterViewModel(repository: InMemoryCounterRepository())
        await vm.increment()
        vm.toastShown()
        #expect(vm.toast == nil)
    }
}
