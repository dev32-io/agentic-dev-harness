package io.dev32.sample

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class CounterViewModelTest {

    @Before
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `state count is 0 initially`() = runTest {
        val vm = CounterViewModel(InMemoryCounterRepository())
        assertEquals(0, vm.state.value.count)
    }

    @Test
    fun `increment intent advances count`() = runTest {
        val vm = CounterViewModel(InMemoryCounterRepository())
        vm.dispatch(CounterIntent.Increment)
        assertEquals(1, vm.state.value.count)
        assertEquals("Incremented", vm.state.value.toast)
    }

    @Test
    fun `toast clears after consume`() = runTest {
        val vm = CounterViewModel(InMemoryCounterRepository())
        vm.dispatch(CounterIntent.Increment)
        vm.dispatch(CounterIntent.ToastShown)
        assertEquals(null, vm.state.value.toast)
    }
}
