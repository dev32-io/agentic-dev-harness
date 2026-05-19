# Hilt DI -- Details & Examples

This file expands `platforms/android/rules/android-hilt-di.md`.
Below: a Singleton module, a ViewModel using constructor
injection, and a test that swaps a fake repository via
`@TestInstallIn`.

## Application

```kotlin
@HiltAndroidApp
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        // Hilt has set up the SingletonComponent by now.
    }
}
```

Register `App` in `AndroidManifest.xml`:

```xml
<application
    android:name=".App"
    ...>
```

## Production module -- Singleton scope

Two patterns mixed in one module:

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    // @Provides -- needs construction logic.
    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    @Provides
    @Singleton
    fun provideAuthApi(client: OkHttpClient): AuthApi = Retrofit.Builder()
        .baseUrl(BuildConfig.API_BASE_URL)
        .client(client)
        .addConverterFactory(MoshiConverterFactory.create())
        .build()
        .create(AuthApi::class.java)
}

// @Binds -- pure interface-to-impl mapping. Lives in an abstract
// class because @Binds methods must be abstract.
@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindAuthRepository(
        impl: DefaultAuthRepository,
    ): AuthRepository
}
```

`DefaultAuthRepository`'s constructor declares its own
dependencies; Hilt builds it:

```kotlin
class DefaultAuthRepository @Inject constructor(
    private val api: AuthApi,
    private val tokenStore: TokenStore,
) : AuthRepository {
    override suspend fun login(email: String, password: String): LoginOutcome {
        ...
    }
}
```

## Injected ViewModel

```kotlin
@HiltViewModel
class LoginViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val analytics: Analytics,
) : ViewModel() {
    // ...
}
```

From a composable:

```kotlin
@Composable
fun LoginScreen(viewModel: LoginViewModel = hiltViewModel()) {
    // Hilt-provided VM; lifetime matches the NavBackStackEntry.
}
```

## Swapping a fake in test -- `@TestInstallIn`

The production `RepositoryModule` provides the real
`AuthRepository`. The test replaces just that one binding:

```kotlin
// Test source set: src/androidTest/java/.../TestRepositoryModule.kt

@Module
@TestInstallIn(
    components = [SingletonComponent::class],
    replaces = [RepositoryModule::class],
)
abstract class TestRepositoryModule {

    @Binds
    @Singleton
    abstract fun bindAuthRepository(
        fake: FakeAuthRepository,
    ): AuthRepository
}

// The fake implementation -- not a mock, a real class with
// in-memory behavior the test can configure.
@Singleton
class FakeAuthRepository @Inject constructor() : AuthRepository {
    var nextOutcome: LoginOutcome = LoginOutcome.NetworkFailure
    override suspend fun login(email: String, password: String): LoginOutcome {
        return nextOutcome
    }
}
```

The test:

```kotlin
@HiltAndroidTest
@UninstallModules(RepositoryModule::class)
class LoginScreenTest {

    @get:Rule(order = 0) val hiltRule = HiltAndroidRule(this)
    @get:Rule(order = 1) val composeRule =
        createAndroidComposeRule<HiltTestActivity>()

    @Inject lateinit var authRepository: AuthRepository

    @Before fun setUp() { hiltRule.inject() }

    @Test
    fun showsErrorOnNetworkFailure() {
        (authRepository as FakeAuthRepository).nextOutcome =
            LoginOutcome.NetworkFailure

        composeRule.setContent { AppTheme { LoginScreen({}, {}) } }
        composeRule.onNodeWithText("Email").performTextInput("a@b.c")
        composeRule.onNodeWithText("Password").performTextInput("hunter2")
        composeRule.onNodeWithText("Submit").performClick()

        composeRule.onNodeWithText("Network unavailable").assertIsDisplayed()
    }
}
```

What this gets us:
- Production code is untouched. The VM still asks for
  `AuthRepository`; the test wires a different binding.
- The fake is a real class with `@Inject constructor` -- Hilt
  builds it the same way it builds production code.
- The test asserts behavior at the screen layer, not at a
  mocked-method-call layer. Refactors that preserve behavior
  don't break the test.

## When to prefer `@Provides` vs `@Binds`

| Use case                                                  | Annotation  |
|-----------------------------------------------------------|-------------|
| "Interface `Foo` is bound to concrete `FooImpl`."         | `@Binds`    |
| "Build a `Retrofit` from a builder."                      | `@Provides` |
| "Read a flag from BuildConfig and return."                | `@Provides` |
| "Bind `OnboardingFlowImpl` to `OnboardingFlow`."          | `@Binds`    |

Rule of thumb: if the body would be `return SomethingImpl(...)`
where the argument list matches a constructor, use `@Binds`.
