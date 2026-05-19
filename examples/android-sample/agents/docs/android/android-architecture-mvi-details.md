# MVI Architecture -- Details & Worked Example

This file expands `platforms/android/rules/android-architecture-mvi.md`.
The example below shows the full flow end-to-end for a Login
screen: `LoginUiState`, `LoginIntent`, `LoginEffect`,
`LoginViewModel`, and the consuming composable.

## LoginUiState

The state holds everything the view needs to render. Note: the
form fields, the in-flight indicator, and the field-level error
are all here. The "go to home" navigation is NOT -- that's an
Effect.

```kotlin
data class LoginUiState(
    val email: String = "",
    val password: String = "",
    val isSubmitting: Boolean = false,
    val emailError: String? = null,
    val passwordError: String? = null,
) {
    val canSubmit: Boolean
        get() = email.isNotBlank() &&
                password.isNotBlank() &&
                !isSubmitting
}
```

`canSubmit` is a derived `val` -- the view reads it directly, no
extra plumbing. This is cheap; for expensive derivations, the
reducer should compute and cache.

## LoginIntent

Every user action and every external event is a variant. Adding
"forgot password tapped" = adding one variant + one reducer arm.

```kotlin
sealed interface LoginIntent {
    data class EmailChanged(val value: String) : LoginIntent
    data class PasswordChanged(val value: String) : LoginIntent
    data object SubmitTapped : LoginIntent
    data object ForgotPasswordTapped : LoginIntent
}
```

## LoginEffect

One-shot side effects. The screen consumes these in a
`LaunchedEffect`; the screen's parent decides what to do.

```kotlin
sealed interface LoginEffect {
    data class NavigateToHome(val userId: UserId) : LoginEffect
    data object NavigateToForgotPassword : LoginEffect
    data class ShowError(val message: String) : LoginEffect
}
```

## LoginViewModel

The reducer is a `when` over the sealed Intent type. Side work
(the actual login call) is launched in `viewModelScope` from
inside the reducer arm.

```kotlin
@HiltViewModel
class LoginViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(LoginUiState())
    val state: StateFlow<LoginUiState> = _state.asStateFlow()

    private val _effects = MutableSharedFlow<LoginEffect>(
        replay = 0,
        extraBufferCapacity = 1,
    )
    val effects: SharedFlow<LoginEffect> = _effects.asSharedFlow()

    fun dispatch(intent: LoginIntent) {
        when (intent) {
            is LoginIntent.EmailChanged -> _state.update {
                it.copy(email = intent.value, emailError = null)
            }
            is LoginIntent.PasswordChanged -> _state.update {
                it.copy(password = intent.value, passwordError = null)
            }
            LoginIntent.SubmitTapped -> submit()
            LoginIntent.ForgotPasswordTapped -> viewModelScope.launch {
                _effects.emit(LoginEffect.NavigateToForgotPassword)
            }
        }
    }

    private fun submit() {
        val current = _state.value
        if (!current.canSubmit) return
        _state.update { it.copy(isSubmitting = true) }
        viewModelScope.launch {
            when (val outcome = authRepository.login(current.email, current.password)) {
                is LoginOutcome.Success -> {
                    _state.update { it.copy(isSubmitting = false) }
                    _effects.emit(LoginEffect.NavigateToHome(outcome.userId))
                }
                is LoginOutcome.InvalidEmail -> _state.update {
                    it.copy(isSubmitting = false, emailError = outcome.reason)
                }
                is LoginOutcome.InvalidPassword -> _state.update {
                    it.copy(isSubmitting = false, passwordError = outcome.reason)
                }
                is LoginOutcome.NetworkFailure -> {
                    _state.update { it.copy(isSubmitting = false) }
                    _effects.emit(LoginEffect.ShowError("Network unavailable"))
                }
            }
        }
    }
}
```

Key properties of this reducer:
- `dispatch` returns `Unit` -- no result, no exceptions.
- Field-level errors live in state; transport failures are
  effects (a snackbar).
- `_state.update { it.copy(...) }` is atomic; safe to call from
  multiple coroutines.

## The composable

The screen is mostly view code. It collects state, collects
effects, threads state down, sends Intents up.

```kotlin
@Composable
fun LoginScreen(
    onLoggedIn: (UserId) -> Unit,
    onForgotPassword: () -> Unit,
    viewModel: LoginViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is LoginEffect.NavigateToHome ->
                    onLoggedIn(effect.userId)
                LoginEffect.NavigateToForgotPassword ->
                    onForgotPassword()
                is LoginEffect.ShowError ->
                    snackbarHostState.showSnackbar(effect.message)
            }
        }
    }

    Scaffold(snackbarHost = { SnackbarHost(snackbarHostState) }) { padding ->
        LoginForm(
            modifier = Modifier.padding(padding),
            state = state,
            onEmailChange = { viewModel.dispatch(LoginIntent.EmailChanged(it)) },
            onPasswordChange = { viewModel.dispatch(LoginIntent.PasswordChanged(it)) },
            onSubmit = { viewModel.dispatch(LoginIntent.SubmitTapped) },
            onForgotPassword = { viewModel.dispatch(LoginIntent.ForgotPasswordTapped) },
        )
    }
}
```

`LoginForm` is the stateless leaf -- it takes `state` and
callbacks. It can be `@Preview`'d with fake state without any
ViewModel involved.

## Testing the reducer

Because the reducer is "state in, state out, no I/O directly,"
unit testing is mechanical: construct a VM with a fake
repository, dispatch intents, assert state.

```kotlin
@Test
fun `submit with valid form navigates to home`() = runTest {
    val fakeAuth = FakeAuthRepository().apply {
        nextOutcome = LoginOutcome.Success(UserId("u-1"))
    }
    val vm = LoginViewModel(fakeAuth)

    vm.dispatch(LoginIntent.EmailChanged("a@b.c"))
    vm.dispatch(LoginIntent.PasswordChanged("hunter2"))

    val effects = mutableListOf<LoginEffect>()
    val job = launch { vm.effects.toList(effects) }

    vm.dispatch(LoginIntent.SubmitTapped)
    advanceUntilIdle()

    assertEquals(false, vm.state.value.isSubmitting)
    assertEquals(LoginEffect.NavigateToHome(UserId("u-1")), effects.single())
    job.cancel()
}
```

This is why we keep state in state and effects in effects: the
test asserts on both shapes independently.
