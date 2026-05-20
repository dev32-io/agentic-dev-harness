package io.dev32.sample

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.serialization.Serializable

@Serializable object CounterRoute

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MaterialTheme {
                Surface {
                    SampleApp()
                }
            }
        }
    }
}

@Composable
fun SampleApp() {
    val nav = rememberNavController()
    NavHost(navController = nav, startDestination = CounterRoute) {
        composable<CounterRoute> { CounterScreen() }
    }
}

@Composable
fun CounterScreen(viewModel: CounterViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(state.toast) {
        state.toast?.let { msg ->
            snackbarHostState.showSnackbar(msg)
            viewModel.dispatch(CounterIntent.ToastShown)
        }
    }

    Scaffold(snackbarHost = { SnackbarHost(snackbarHostState) }) { padding ->
        CounterContent(
            modifier = Modifier.padding(padding),
            count = state.count,
            onIncrement = { viewModel.dispatch(CounterIntent.Increment) },
        )
    }
}

@Composable
fun CounterContent(
    count: Int,
    onIncrement: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier) {
        Text(text = "$count", modifier = Modifier.testTag("count"))
        Button(onClick = onIncrement, modifier = Modifier.testTag("increment")) {
            Text("Increment")
        }
    }
}
