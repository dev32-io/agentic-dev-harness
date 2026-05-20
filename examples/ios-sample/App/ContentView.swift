import SwiftUI

struct ContentView: View {
    @State private var vm = CounterViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Text("\(vm.count)")
                .font(.largeTitle)
                .accessibilityIdentifier("count")
            Button("Increment") {
                Task { await vm.increment() }
            }
            .accessibilityIdentifier("increment")
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .alert("Status", isPresented: .constant(vm.toast != nil)) {
            Button("OK") { vm.toastShown() }
        } message: {
            Text(vm.toast ?? "")
        }
    }
}

#Preview("default") {
    ContentView()
}
