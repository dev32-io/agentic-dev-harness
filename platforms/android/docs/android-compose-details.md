# Jetpack Compose -- Details & Examples

This file expands `platforms/android/rules/android-compose.md`.
The rule states the bar; this doc shows the patterns and the
recomposition gotchas that catch agents off-guard.

## State hoisting -- the canonical shape

The "hoisted" version separates the controller from the view.
The controller (screen) owns state; the view (component) is pure.

```kotlin
// Stateless component -- reusable, previewable, no VM.
@Composable
fun NameField(
    name: String,
    onNameChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    OutlinedTextField(
        value = name,
        onValueChange = onNameChange,
        label = { Text("Name") },
        modifier = modifier,
    )
}

// Stateful screen -- owns state via VM, threads state down.
@Composable
fun NameScreen(viewModel: NameViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    NameField(
        name = state.name,
        onNameChange = { viewModel.dispatch(NameIntent.Edit(it)) },
    )
}

@Preview
@Composable
private fun NameFieldPreview() {
    AppTheme {
        NameField(name = "Ada Lovelace", onNameChange = {})
    }
}
```

`NameField` doesn't know `NameViewModel` exists. That's the
property that makes it reusable and previewable.

## `derivedStateOf` for expensive computed values

A naive computed value in the body recomputes on every
recomposition:

```kotlin
// BAD: filteredItems recomputes every recomposition, even when
// `items` and `query` haven't changed.
@Composable
fun ItemList(items: List<Item>, query: String) {
    val filteredItems = items.filter { it.matches(query) }
    LazyColumn { items(filteredItems) { ItemRow(it) } }
}
```

`derivedStateOf` memoizes against the State reads inside its
block. Recomputes only when those reads change:

```kotlin
// GOOD: filteredItems recomputes only when items OR query change.
@Composable
fun ItemList(items: List<Item>, query: String) {
    val filteredItems by remember(items, query) {
        derivedStateOf { items.filter { it.matches(query) } }
    }
    LazyColumn { items(filteredItems) { ItemRow(it) } }
}
```

`derivedStateOf` is for "many State reads → one computed value
that doesn't change as often." If the computation is cheap, skip
it -- the wrapper itself has overhead.

## `produceState` for one-shot async loads

When you need to start an async load when a composable enters
the composition and surface its result as state:

```kotlin
@Composable
fun UserAvatar(userId: UserId, repo: UserRepository) {
    val avatarState by produceState<AvatarState>(
        initialValue = AvatarState.Loading,
        userId,
    ) {
        value = try {
            AvatarState.Loaded(repo.loadAvatar(userId))
        } catch (e: IOException) {
            AvatarState.Error(e)
        }
    }

    when (val s = avatarState) {
        AvatarState.Loading -> Spinner()
        is AvatarState.Loaded -> Image(s.bitmap, null)
        is AvatarState.Error -> ErrorIcon()
    }
}
```

`produceState` is a `LaunchedEffect` + `remember { mutableStateOf }`
in one helper. Reach for it when the source is async and the sink
is a single State.

## Common recomposition gotchas

### Lambda capture without `remember`

```kotlin
// BAD: lambda is a new instance every recomposition, breaking
// MyButton's skippability.
@Composable
fun Screen(viewModel: VM) {
    MyButton(onClick = { viewModel.click() })
}

// GOOD: stable lambda reference across recomposition.
@Composable
fun Screen(viewModel: VM) {
    val onClick = remember(viewModel) { { viewModel.click() } }
    MyButton(onClick = onClick)
}
```

In practice, method-reference form (`viewModel::click`) is also
stable -- Compose treats it as referentially equal.

### Reading State outside its scope

```kotlin
// BAD: by-getter outside the composable function body. The
// State read isn't tracked; updates don't trigger recomposition.
class BadHelper(val state: State<Int>) {
    fun render() = Text("${state.value}")  // unreliable
}
```

Always read `State.value` (or use `by`) inside a `@Composable`
function, where the runtime can observe the read.

### Unstable list parameters

```kotlin
// PROBABLY UNSTABLE: List<T> is an interface; the compiler
// can't prove the implementation is immutable.
@Composable
fun Items(items: List<Item>) { ... }

// STABLE: ImmutableList from kotlinx.collections.immutable, or
// wrap in @Immutable class.
@Immutable
data class ItemList(val items: List<Item>)

@Composable
fun Items(list: ItemList) { ... }
```

If profiling shows a list-taking composable recomposes too
often, this is the usual cause.

## Effect lifecycle quick reference

```kotlin
// LaunchedEffect: keyed coroutine.
LaunchedEffect(userId) {
    // Re-runs when userId changes; cancels on leaving composition.
    val user = repo.load(userId)
    snackbarHost.showSnackbar("Loaded ${user.name}")
}

// DisposableEffect: setup + teardown.
DisposableEffect(lifecycleOwner) {
    val observer = LifecycleEventObserver { _, event -> ... }
    lifecycleOwner.lifecycle.addObserver(observer)
    onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
}

// SideEffect: runs after every successful composition.
SideEffect {
    analytics.screenView(screenName)
}
```

Pick by lifetime requirement: coroutine that should cancel
(`LaunchedEffect`), resource that needs cleanup (`DisposableEffect`),
fire-and-forget every frame (`SideEffect`).
