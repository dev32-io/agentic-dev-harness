package io.dev32.sample

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import javax.inject.Inject
import javax.inject.Singleton

interface CounterRepository {
    val count: StateFlow<Int>
    suspend fun increment()
}

@Singleton
class InMemoryCounterRepository @Inject constructor() : CounterRepository {
    private val _count = MutableStateFlow(0)
    override val count: StateFlow<Int> = _count.asStateFlow()
    override suspend fun increment() {
        _count.update { it + 1 }
    }
}
