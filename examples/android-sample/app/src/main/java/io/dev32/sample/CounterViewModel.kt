package io.dev32.sample

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CounterUiState(
    val count: Int = 0,
    val toast: String? = null,
)

sealed interface CounterIntent {
    data object Increment : CounterIntent
    data object ToastShown : CounterIntent
}

@HiltViewModel
class CounterViewModel @Inject constructor(
    private val repository: CounterRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(CounterUiState())
    val state: StateFlow<CounterUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            repository.count.collect { c ->
                _state.update { it.copy(count = c) }
            }
        }
    }

    fun dispatch(intent: CounterIntent) {
        when (intent) {
            CounterIntent.Increment -> viewModelScope.launch {
                repository.increment()
                _state.update { it.copy(toast = "Incremented") }
            }
            CounterIntent.ToastShown -> _state.update { it.copy(toast = null) }
        }
    }
}
